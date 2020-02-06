searchUnattachedManagedDisk() {
    query='resources | extend disk_tags =  bag_keys(tags) | extend disk_tags_string = tostring(disk_tags) | where type == "microsoft.compute/disks" | where properties.diskState == "Unattached" | where disk_tags_string !contains_cs "ASR-ReplicaDisk"  | project resourceGroup, name, sku.name, location, diskSizeGB=toint(properties.diskSizeGB), diskState=tostring(properties.diskState), properties.timeCreated | summarize sum(diskSizeGB) by tostring(sku_name)' 
    echo az graph query -q "$query"
    az graph query -q "$query"
}

searchUnattachedManagedDisk