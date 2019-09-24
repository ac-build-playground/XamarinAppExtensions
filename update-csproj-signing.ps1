# Script for updating Xamarin.iOS signing configuration
# For each csproj file it looks for corresponding Info.plist to get its bundleId
# Then if detected bundle id matches one of specified id in arguments it sets <CodesignProvision> to corresponding profile UUID
#
# TargetBundleIds - comma separated list of target bundle ids,
#   e.g. "com.test.container,com.test.today-extension,com.test.watch-extension,"
# ProvisionProfileUuids - comma separated list of provision profile UUIDs
#

param([String] $TargetBundleIds, [String] $ProvisionProfileUuids);

Write-Host "TargetBundleIds:" $TargetBundleIds
Write-Host "ProvisionProfileUuids:" $ProvisionProfileUuids

# validation

if (!$TargetBundleIds) {
  Write-Host "TargetBundleIds is required"
  exit 1;
}

if (!$ProvisionProfileUuids) {
  Write-Host "ProvisionProfileUuids is required"
  exit 1;
}

[String[]]$TargetBundleIdsParsed = $TargetBundleIds.Split(",");
[String[]]$ProvisionProfileUuidsParsed = $ProvisionProfileUuids.Split(",");

if (!$TargetBundleIdsParsed.Length) {
  Write-Host "TargetBundleIds should be comma-separated string array"
  exit 1;
}

if (!$ProvisionProfileUuidsParsed.Length) {
  Write-Host "ProvisionProfileUuids should be comma-separated string array"
  exit 1;
}

if ($TargetBundleIdsParsed.Length -ne $ProvisionProfileUuidsParsed.Length) {
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
    for ($i = 0; $i -lt $TargetBundleIdsParsed.Length; $i++) {
      $bundleId = $TargetBundleIdsParsed[$i];
      Write-Host $i $TargetBundleIdsParsed.Length "Checking bundle" $bundleId $projectBundleId
      if ($bundleId -eq $projectBundleId) {
        Write-Host "Match!"
        $codesignProvision = $ProvisionProfileUuidsParsed[$i];
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
        break;
      }
    }
  }
}

# entry point
ProcessCsprojFiles