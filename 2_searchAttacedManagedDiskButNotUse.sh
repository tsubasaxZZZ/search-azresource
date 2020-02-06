#!/bin/sh

if [ ! -d temp ]; then
    mkdir temp
fi

if [ -f disallocated-vm.txt ]; then
    echo -n "Already execute this tool. Do you want to run repeat? (y/n) " 
    while read yn
    do
        case $yn in
            [yY])
                break
                ;;
            [nN])
                echo exited
                exit 1
                ;;
        esac
    done
fi


# 仮想マシンの一覧を取得
az graph query --graph-query 'resources | where type=="microsoft.compute/virtualmachines" | project id,resourceGroup,name' --first 5000 -o tsv > vmlist.txt


# 1か月間割り当て解除されている VM の一覧を取得
getDeallocatedVM(){
    vmcount=$(wc -l vmlist.txt | cut -d" " -f1)
    i=1
    >disallocated-vm.txt
    cat vmlist.txt | while read id vmname resourceGroup
    do
        #az monitor metrics list -g $resourceGroup --resource $vmname --resource-type "microsoft.compute/virtualmachines" --metric "Percentage CPU" --start-time 2020-01-01T00:00:00+9 --end-time 2020-01-31 --interval 24h
        printf "start get metrics : %s(%d/%d)\n" $vmname $i $vmcount
        az monitor metrics list --resource $id --metric "Percentage CPU" --start-time 2020-01-01T00:00:00+9 --end-time 2020-01-31 --interval 24h --query 'value[0].timeseries[0].data' -o tsv > temp/${resourceGroup}_${vmname}.txt
        averageNum=$(cat temp/${resourceGroup}_${vmname}.txt | cut -f1 | grep -v None | wc -l)
        if [ $averageNum -eq 0 ]; then
            printf "%s has not been boot in a month.\n" $vmname
            echo "$id|$resourceGroup|$vmname" >> disallocated-vm.txt
        else
            printf "%s has been boot in a month.\n" $vmname
        fi
        printf "end get metrics : %s\n" $vmname
        i=$((i+1))
    done
}

# 1か月間割り当て解除されている VM のディスクを取得
getDeallocatedVMsDisksInformation(){
    vmlist=
    for l in `cat disallocated-vm.txt`
    do
        id=$(echo $l | cut -d"|" -f 1)
        resourceGroup=$(echo $l | cut -d"|" -f 2)
        vmName=$(echo $l | cut -d"|" -f 3)
        vmlist="'$id',$vmlist"
    done
    vmlist=$(echo $vmlist | sed 's/,$//')

    # 管理ディスクの一覧を取得
    az graph query --graph-query "resources | where type=='microsoft.compute/virtualmachines' | where id in~ ($vmlist) " --query "[].[name,properties.storageProfile.osDisk.managedDisk.id,properties.storageProfile.dataDisks[].managedDisk.id]" --first 5000 -o json > attachedManagedDisktoUnusedVM.txt

    # 管理ディスク情報を取得
    # リソース グループ単位で管理ディスクの一覧を出力
    \rm -f temp/*_disks.txt
    for l in `cat attachedManagedDisktoUnusedVM.txt | grep "/subscriptions" | sed -e 's/ //g' -e 's/"//g' -e 's/,//g'`
    do
        diskId=$l
        resourceGroup=$(echo $diskId | cut -d'/' -f5)
        echo $diskId >> temp/${resourceGroup}_disks.txt
    done

    # リソース グループ単位でグラフクエリ
    >reservedUnusedVmManagedDisks.csv
    for l in temp/*_disks.txt
    do
        diskIds=
        for id in `cat $l`
        do
            diskIds="'$id',$diskIds"
        done
        diskIds=$(echo $diskIds | sed 's/,$//')
        echo az graph query --graph-query "resources | where id in~ ($diskIds) | project resourceGroup,name,sku.name,properties.diskSizeGB"
        az graph query --graph-query "resources | where id in~ ($diskIds) | project resourceGroup,name,sku.name,properties.diskSizeGB" --first 5000 -o tsv >> reservedUnusedVmManagedDisks.csv
    done


#    diskIds=$(echo $diskIds | sed 's/,$//')
#    az graph query --graph-query "resources | where id in ($diskIds)" --first 5000

}

#getDeallocatedVM
getDeallocatedVMsDisksInformation
