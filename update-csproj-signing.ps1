param([String[]] $TargetBundleIds, [String[]] $ProvisionProfileUuids);

if (!$TargetBundleIds -or !$ProvisionProfileUuids -or !$TargetBundleIds.Length  -or !$ProvisionProfileUuids.Length) {
  exit 0;
}

$targetBundleIds = $TargetBundleIds.Split(",");
$provisionProfileUuids = $ProvisionProfileUuids.Split(",");

function ProcessCsprojFiles {
  Get-ChildItem -Path "./" -Filter "*.csproj" -Recurse -File -Name | ForEach-Object {
    ParseCsprojFile $_
  }

  exit 0;
}

# parse csproject file
function ParseCsprojFile {
  $projectPath = $args[0];
 
  Write-Host "==============="
  Write-Host "Processing" $projectPath;
  
  # gettign info.plist file
  $infoPlistPath = (Split-Path $projectPath -Parent) + "/Info.plist";
  $projectBundleId;

  if (!(Test-Path -Path $infoPlistPath)) {
    Write-Host "Didn't find Info.plist at" $infoPlistPath;
    return;
  }

  [xml]$plistXml = Get-Content $infoPlistPath;

  $plistXml.plist.dict | Foreach {
    $_.SelectNodes("key") | Foreach {
      if ($_."#text" -eq "CFBundleIdentifier") {
        $projectBundleId = $_.NextSibling."#text";
        Write-Host "Found bundle id:" $projectBundleId;
      }
    }
  }

  if (!$projectBundleId) {
    Write-Host "Bundle id wasn't found";
    exit 0;
  }

  [xml]$csprojXml = Get-Content $projectPath;
  $project = $csprojXml.Project;

  if ($csprojXml.Project -and $csprojXml.Project.PropertyGroup) {
    $updated = false
    for ($i = 0; $i -lt $targetBundleIds.Length; $i++) {
      $bundleId = $targetBundleIds[$i];
      if ($bundleId -eq $projectBundleId) {
        $codesignProvision = $provisionProfileUuids[$i];
        foreach ($propertyGroup in $csprojXml.Project.PropertyGroup) {
          if ($propertyGroup.CodesignProvision) {
            $propertyGroup.CodesignProvision = $codesignProvision;
          } else {
            $node = $csprojXml.CreateElement("CodesignProvision", $project.NamespaceURI);
            $node.innerText = $codesignProvision;
            $propertyGroup.AppendChild($node);
          }
        }

        $csprojXml.Save($projectPath);
        $updated = true
        Write-Host "Updated" $projectPath "with" $codesignProvision;
      }
    }

    if (!$updated) {
      Write-Host $projectPath "wasn't updated"
    }
  }
}

# entry point
ProcessCsprojFiles