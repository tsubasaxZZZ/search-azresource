#!/bin/sh

THRESHOLD=100
az graph query --graph-query 'resources | where type=="microsoft.compute/virtualmachines" | project id,resourceGroup,name,properties.hardwareProfile.vmSize' --first 5000 -o tsv > vmlist_with_size.txt
# 低いCPU使用率のVMを取得
getLowUseCPUVM(){
    vmcount=$(wc -l vmlist.txt | cut -d" " -f1)
    i=1
    >lowCPUVM.csv
    cat vmlist_with_size.txt | while read id vmname resourceGroup vmSize
    do
        printf "start get metrics : %s(%d/%d)\n" $vmname $i $vmcount
        cpu_percent=$(az monitor metrics list --resource $id  --metric "Percentage CPU" --start-time 2020-01-01T00:00:00+9 --end-time 2020-01-31 --interval 24h --query 'avg(value[0].timeseries[0].data[*].average)' -o tsv)
        # 過去の期間で起動していて、かつしきい値以下の VM を抽出
        if [ x$cpu_percent != x"" ]; then
            if [ $(echo "$cpu_percent <= $THRESHOLD" | bc) -eq 1 ]; then
                echo $id $vmname $resourceGroup $vmSize $cpu_percent >> lowCPUVM.csv
            fi
        fi
        printf "end get metrics : %s\n" $vmname
        i=$((i+1))
    done
             #az graph query --graph-query "resources | where id=$id" --first 5000
}

getLowUseCPUVM