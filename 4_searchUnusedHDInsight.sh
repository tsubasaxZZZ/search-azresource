#!/bin/sh

az graph query --graph-query 'resources | where type == "microsoft.hdinsight/clusters"| project id,name,resourceGroup' --first 5000 -o tsv > hdinsightlist.txt
# 低いCPU使用率のVMを取得
getLowUseCPUVM(){
    count=$(wc -l hdinsightlist.txt | cut -d" " -f1)
    i=1
    >lowusageHdinsight.csv
    cat hdinsightlist.txt | while read id name resourceGroup
    do
        printf "start get metrics : %s(%d/%d)\n" $name $i $count
        usage=$(az monitor metrics list --resource $id  --metric "GatewayRequests" --start-time 2020-01-01T00:00:00+9 --end-time 2020-01-31 --interval 24h --query 'value[0].timeseries[0].data[*].total' -o json)
        # 過去の期間で起動していて、かつしきい値以下の VM を抽出
        if [ x"$usage" = x"" ]; then
            echo $id $name $resourceGroup >> lowusageHdinsight.csv
        fi
        printf "end get metrics : %s\n" $vmname
        i=$((i+1))
    done
             #az graph query --graph-query "resources | where id=$id" --first 5000
}

getLowUseCPUVM