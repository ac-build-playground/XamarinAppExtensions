# Script for updating Xamarin.iOS signing configuration
# For each csproj file it looks for corresponding Info.plist to get its bundleId
# Then if detected bundle id matches one of specified id in arguments it sets <CodesignProvision> to corresponding profile UUID
#
# TargetBundleIds - comma separated list of target bundle ids,
#   e.g. "com.test.container,com.test.today-extension,com.test.watch-extension,"
# ProvisionProfileUuids - comma separated list of provision profile UUIDs
#

param([String] $TargetBundleIds, [String] $ProvisionProfileUuids);

# validation

if (!$TargetBundleIds) {
  Write-Host "TargetBundleIds is required"
  exit 1;
}

if (!$ProvisionProfileUuids) {
  Write-Host "ProvisionProfileUuids is required"
  exit 1;
}

[String[]]$TargetBundleIds = $TargetBundleIds.Split(",");
[String[]]$ProvisionProfileUuids = $ProvisionProfileUuids.Split(",");

if (!$TargetBundleIds.Length) {
  Write-Host "TargetBundleIds should be comma-separated string array"
  exit 1;
}

if (!$ProvisionProfileUuids.Length) {
  Write-Host "ProvisionProfileUuids should be comma-separated string array"
  exit 1;
}

if ($TargetBundleIds.Length -ne $ProvisionProfileUuids.Length) {
  Write-Host "TargetBundleIds and ProvisionProfileUuids should be the same length"
  exit 1;
}

function ProcessCsprojFiles {
  Get-ChildItem -Path "./" -Filter "*.csproj" -Recurse -File -Name | ForEach-Object {
    ParseProject $_
  }

  exit 0;
}

# parse csproject file
function ParseProject {
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
    return;
  }

  [xml]$csprojXml = Get-Content $projectPath;
  $project = $csprojXml.Project;

  if ($csprojXml.Project -and $csprojXml.Project.PropertyGroup) {
    Write-Host $TargetBundleIds.Length
    for ($i = 0; $i -lt $TargetBundleIds.Length; $i++) {
      $bundleId = $TargetBundleIds[$i];
      Write-Host $bundleId $TargetBundleIds[$i]
      if ($bundleId -eq $projectBundleId) {
        $codesignProvision = $ProvisionProfileUuids[$i];
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
        Write-Host "Updated" $projectPath "with" $codesignProvision;
      }
    }
  }
}

# entry point

Write-Host ""
Write-Host "Looking fow following bundle ids:"
Write-Host $TargetBundleIds | Format-List
Write-Host ""
Write-Host "Updating with following provision profile UUIDs:"
Write-Host $ProvisionProfileUuids | Format-List
Write-Host ""

ProcessCsprojFiles