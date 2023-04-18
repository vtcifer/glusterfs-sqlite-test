# glusterfs-sqlite-test
A simple testing script for sqlite3 on the glusterfs parallel file system

This is designed to test/validate that the gluster volume and mount options for the clients are correct to enable the posix advisory locking of sqlite to maintain the ACID properties required for transactional databases.

# Usage:
The test uses docker containers using the official ruby images and the sqlite ruby gem to interface with the sqlite db.  

You'll need to build the image from the Dockerfile in this repo using `docker buildx build . -t <your name and tags>` By default it uses the latest slim version (ruby:slim) but you can override this using `--build-arg TAG={tag}` to get a different version and `--build-arg BASE={base}` to get a different base image (you'll need to ensure ruby is present in that base).  

The Dockerfile will install the sqlite3 libraries, and gem.  If you make changes to the BASE image, you may need to adjust the installatin of those libraries + gem.

It will also copy the testing script into the image and set that to run.

The testing script creates an sqlite db (shared.db3) in /hooks, which should be a bind mount on your gluster volume.  It attempts to INSERT/UPDATE entries constantly, check on consistency after every 20 successful transactions, and outputing the contents of the table.

## Execute tests on single nodes:
To run on a single docker node use the following syntax:
```
docker run \
    --rm \
    --name {name} \
    --mount type=bind,source={path to your gluster mount}/hooks/,destination=/hooks \
    {your name and tag}
```

Execute that on each node.  You can monitor the output of the test script by using the `docker logs -f {container}` command.  You should see output similar to the following after some time.
```
hostname is 353312cf9ce7
opening db
db open
preparing db
failed prepare - database is locked
preparing db
db prepared
...
DB Integrity check:
[["ok"]]
Table contents:
353312cf9ce7|2023-04-18 15:53:24|1060
db9d7cd4070e|2023-04-18 15:53:22|1089
6c3038201498|2023-04-18 15:53:20|1031
```

## Execute tests on swarm 
To run in swarm use the following syntax:

```
docker service create \
    --name {service name} \
    --replicas {#} \
    --replicas-max-per-node 1 \
    --mount type=bind,source={path to your gluster mount}/hooks/,destination=/hooks \
    {your name and tag}
```
Where `--replicas {#}` is the number of nodes in your swarm.  You could add more, but this combined with `--replicas-max-per-node 1` ensures one container per node.

You can monitor the output of the test script in this case by using the `docker service logs -f {service name}` command.  You should see similar output as the above, but prefixed with service/task ids and for all nodes in one place.
```
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | hostname is 7b47943e3b0e
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | opening db
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | db open
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | preparing db
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | db prepared
gfsdbtest.3.u3k2t1cmj8cy@lichswarm2    | hostname is 4b34ca65d590
gfsdbtest.3.u3k2t1cmj8cy@lichswarm2    | opening db
gfsdbtest.3.u3k2t1cmj8cy@lichswarm2    | db open
gfsdbtest.3.u3k2t1cmj8cy@lichswarm2    | preparing db
gfsdbtest.3.u3k2t1cmj8cy@lichswarm2    | db prepared
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | hostname is dee0c6073477
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | opening db
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | db open
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | preparing db
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | db prepared
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | DB Integrity check:
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | [["ok"]]
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | Table contents:
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | dee0c6073477|2023-04-18 16:02:42|20
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | 7b47943e3b0e|2023-04-18 16:02:41|18
gfsdbtest.1.v6w68ltsxrqr@lichswarm9    | 4b34ca65d590|2023-04-18 16:02:40|17
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | DB Integrity check:
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | [["ok"]]
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | Table contents:
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | 7b47943e3b0e|2023-04-18 16:02:50|20
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | 4b34ca65d590|2023-04-18 16:02:48|19
gfsdbtest.2.wbuduifs9q9l@lichswarm1    | dee0c6073477|2023-04-18 16:02:42|20
```

So long as you see `[["ok"]]` after the DB Integrity check, your DB is consistent on that node, with no corruption.


# Current Gluster Volume /Mount Settings:
The below is my current gluster volume settings

    $ sudo gluster vol info gfs-lich
    Volume Name: gfs-lich
    Type: Replicate
    Volume ID: 586ef447-8491-4ea5-863f-6308a95b802f
    Status: Started
    Snapshot Count: 0
    Number of Bricks: 1 x 3 = 3
    Transport-type: tcp
    Bricks:
    Brick1: lichswarm1.docker.local:/data/glusterfs/gfs.lich/brick1/brick
    Brick2: lichswarm2.docker.local:/data/glusterfs/gfs.lich/brick1/brick
    Brick3: lichswarm9.docker.local:/data/glusterfs/gfs.lich/brick1/brick
    Options Reconfigured:
    performance.strict-o-direct: on
    performance.open-behind: off
    locks.mandatory-locking: optimal
    performance.client-io-threads: off
    nfs.disable: on
    transport.address-family: inet
    storage.fips-mode-rchecksum: on
    cluster.granular-entry-heal: on
    performance.read-ahead: off
    performance.write-behind: off
    performance.readdir-ahead: off
    performance.parallel-readdir: off
    performance.quick-read: off
    performance.stat-prefetch: off
    performance.io-cache: off
    performance.flush-behind: off
    cluster.self-heal-daemon: enable

I believe the following are defaults even though they are listed as "Reconfigured" 

    nfs.disable: on
    transport.address-family: inet
    storage.fips-mode-rchecksum: on
    cluster.granular-entry-heal: on
    cluster.self-heal-daemon: enable
The below are my client mount settings:

    lichswarm.docker.local:/gfs-lich   /mnt/gfs/lich   glusterfs   defaults,_netdev,direct-io-mode=true   0 0

I've removed the `backup-volfile-servers` mount option for readability, which is simply a list of the each of the individual gluster nodes. 

# Background:
I was setting up a home lab on a raspberry-pi cluster to get some practical experience with docker-swarm and parallel computing.  Part of that involved software with an sqlite database.  I was occasionally experiencing corruption of the database, when different containers running on different nodes would access/modify the database at the same time.  As GlusterFS indicated that it supports the posix advisory locks required by sqlite to maintain the database consistency, the corruption was curious to me.  Digging into this I found numerous examples of other people having similar issues.  The result of that digging ended in this test suite to make sure that I had all settings correct.

# References
The following discussions were key to my making the above listed configuration.

https://lists.gluster.org/pipermail/gluster-users/2018-March/033656.html
https://lists.gluster.org/pipermail/gluster-devel/2016-February/048425.html

