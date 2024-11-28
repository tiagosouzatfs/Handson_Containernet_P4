#!/usr/bin/python
"""
This is the simplest example to showcase Containernet with enabled and containerized P4 switch.
"""
import os

from containernet.net import Containernet
from containernet.node import DockerP4Switch
from containernet.cli import CLI
from mininet.log import info, setLogLevel


def topology():
    net = Containernet()

    info('*** Adding docker containers\n')
    h1 = net.addHost('h1', ip='10.0.0.1/8', mac="00:00:00:00:00:01")
    h2 = net.addHost('h2', ip='10.0.0.2/8', mac="00:00:00:00:00:02")
    h3 = net.addHost('h3', ip='10.0.0.3/8', mac="00:00:00:00:00:03")

    path = os.path.dirname(os.path.abspath(__file__))
    json_file = '/root/hcp.json' # container directory
    config = path + '/p4_files/rules_statics_forward.txt'
    args = {'json': json_file, 'switch_config': config}

    info('*** Adding P4 Switch\n')
    # IPBASE: subnet from eth0 interface,
    s1 = net.addSwitch('s1', cls=DockerP4Switch,
                       volumes=[path + "/p4_files:/root"],
                       dimage="ramonfontes/bmv2", cpu_shares=20,
                       netcfg=True, thriftport=50001,
                       IPBASE="172.17.0.0/16", **args)

    net.addLink(h1, s1, txo=False, rxo=False)
    net.addLink(h2, s1, txo=False, rxo=False)
    net.addLink(h3, s1, txo=False, rxo=False)

    info('*** Starting network\n')
    net.build()
    s1.start([])
    net.staticArp()

    info('*** Running CLI\n')
    CLI(net)

    info('*** Stopping network\n')
    net.stop()


if __name__ == '__main__':
    setLogLevel('info')
    topology()


# p4c --target bmv2 --arch v1model hcp.p4