ceph-zabbix
===========
#### 参考：
https://github.com/BodihTao/ceph-zabbix

改动
===========
> 针对ceph-mimic版本
1. 修改wrops、rdops、ops、rops、wops、mon、rados、pg等监控项获取命令
2. 由于未使用agent，全部类型改为Zabbix采集器
3. 添加监控项ceph.health_status（健康状态）、ceph.health_detail（详细健康状态）、ceph.mds_memory_percent（mds内存使用率）
4. 修改ceph.rados_free、ceph.rados_used、ceph.rados_total变量类型，从数字改为文本；修改ceph.rados_used_ratio类型为浮点数
5. 触发器修改
6. 添加加监控项ceph.tag，消除flag set warning(目前支持noout|noscrub|nodeep-scrub)
7. 配置server和client地址获取


使用
===========
```
* * * * * /etc/zabbix/scripts/ceph-status.sh
```