#!/usr/bin/python

import os # Interagir com pastas e arquivos do sistema operacional

from containernet.net import Containernet # Criação de redes com containers docker
from containernet.node import DockerP4Switch # Classe de switch P4 containerizado
from containernet.cli import CLI # Interagir com os elementos na topologia de rede criada
from mininet.log import info, setLogLevel # Definição do nível de log

# Função para criar a topologia
def topology(): 
    # Criação uma instância de rede dockerizada
    net = Containernet()
    # Adicionando os hosts com ip e mac definidos
    info('*** Adding docker containers\n')
    h1 = net.addHost('h1', ip='10.0.0.1/8', mac="00:00:00:00:00:01")
    h2 = net.addHost('h2', ip='10.0.0.2/8', mac="00:00:00:00:00:02")
    h3 = net.addHost('h3', ip='10.0.0.3/8', mac="00:00:00:00:00:03")
    # Pegar o diretório atual do script
    path = os.path.dirname(os.path.abspath(__file__))
    # Arquivo de compilação do P4 para utilizar no switch
    json_file = '/root/hcp_v3.json' # Diretório dentro do container
    # Tabela de encaminhamento
    config = path + '/p4_files/rules_statics_forward_v3.txt'
    # Argumentos para o switch
    args = {'json': json_file, 'switch_config': config}

    info('*** Adding P4 Switch\n')
    # IPBASE: subnet from eth0 interface do docker
    # Adicionando um switch
    s1 = net.addSwitch('s1', # Nome do switch
                       cls=DockerP4Switch, # Classe do swtich
                       volumes=[path + "/p4_files:/root"], # Volume para o switch ler os arquivos
                       dimage="ramonfontes/bmv2", # imagem do switch modelo bmv2
                       cpu_shares=20, # Limitar os recursos de cpu do container do switch
                       netcfg=True, # Define as informações de rede switch automaticamente
                       thriftport=50001, # O bmv2 utiliza o protoclo thrift para receber ou enviar informações e comandos
                       IPBASE="172.17.0.0/16", # subrede que o docker utiliza para comunicação dos containers com o switch
                       **args)
    # Adicionando os links entre os hosts e o switch
    net.addLink(h1, s1, txo=False, rxo=False) # txo e rxo são filas de transmissão e recepção quando falso, não passa por otimizações
    net.addLink(h2, s1, txo=False, rxo=False) #   ou buffers configurados pelo driver do sistema operacional, então fica definido
    net.addLink(h3, s1, txo=False, rxo=False) #   como falso com o objetivo de simplificar o comportamento da rede.

    info('*** Starting network\n')
    # Aqui realmente contrói a topologia
    net.build()
    # Inicia o switch sem controladores externos
    s1.start([])
    # Define entradas arp estáticas para os hosts, ou seja,
    #   os ips e macs são mapeados diretamente no switch
    #   para evitar consulta arp dinâmica.
    net.staticArp()

    info('*** Running CLI\n')
    # Abre a cli do containernet
    CLI(net)

    info('*** Stopping network\n')
    # terminar a rede e liberar os recursos
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    topology()


# p4c --target bmv2 --arch v1model hcp_v3.p4