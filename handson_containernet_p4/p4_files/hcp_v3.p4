/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800; // Tipo do protocolo no header do frame ethernet (ethertype)
const bit<8> PROTOCOL_TCP = 0x06; // Código do protocolo ICMP em hexadecimal no header do pacote ipv4

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

// typedef define estruturas personalizadas para um determinado tamanho de bits
typedef bit<9>  egressSpec_t; // representa a porta de saída do switich com 9 bits
typedef bit<48> macAddr_t; // representa o endereço mac com 48 bits
typedef bit<32> ip4Addr_t; // representada o endereço ipv4 com 32 bits

// cabeçalho do frame ethernet
header ethernet_t {
    macAddr_t dstAddr; // endereço mac de destino
    macAddr_t srcAddr; // endereço mac de origem
    bit<16>   etherType; // tipo do protocolo encapsulado no frame ethernet
}

// cabeçalho do pacote ipv4
header ipv4_t { 
    bit<4>    version; // versão do protocolo
    bit<4>    ihl; // tamanho do cabeçalho em unidades dividas pelos 32 bits => 4 octetos de bits
    bit<8>    diffserv; // controle de qualidade de serviço
    bit<16>   totalLen; // número do comprimento total do pacote ipv4
    bit<16>   identification; // identificação dos fragmentos do pacote para pacotes maiores do que o MTU da rede
    bit<3>    flags; // utilizado para o controle de fragmentação do pacote
    bit<13>   fragOffset; // utilizado para o controle de fragmentação do pacote
    bit<8>    ttl; // tempo de vida do pacote
    bit<8>    protocol; // define o tipo do protocolo da camada superior
    bit<16>   hdrChecksum; // verificação do cabeçalho ipv4
    ip4Addr_t srcAddr; // endereço ipv4 de origem
    ip4Addr_t dstAddr; // endereço ipv4 de destino
}

// cria uma estrutura adicional de dados para os pacotes
// esse código não utilizado metadados
struct metadata {
    /* empty */
}

// cria uma estrutura chamada headers que avi comportar os headers do frame ethernet e do protocolo ipv4
struct headers {
    ethernet_t   ethernet; // header frame ethernet
    ipv4_t       ipv4; // header pacote ipv4
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

// analise e identifica os cabeçalhos presentes
parser MyParser(packet_in packet, // redebe o pacote de entrada que será processado pelo parser
                out headers hdr, // define a variável de saída onde os cabeçalhos extraídos serão armazenados. Neste caso, a estrutura hdr contém dois cabeçalhos: ethernet e ipv4
                inout metadata meta, // Recebe e envia metadados relacionados ao pacote. Este campo não está sendo utilizado neste código, mas geralmente armazena informações extras para controle de processamento
                inout standard_metadata_t standard_metadata // Esse parâmetro é usado para armazenar metadados padrão do pacote, como informações sobre a egress (porta de saída), ttl, etc. Também não está sendo utilizado diretamente na função MyParser, mas poderia ser utilizada em outras partes do código
                ) {

    // estado inicial quando o pacote chega (estado padrão)
    state start {
        packet.extract(hdr.ethernet); // primeiramente, extrair o cabeçalho ethernet do pacote
        transition select(hdr.ethernet.etherType) // verificar qual protocolo está encapsulado no pacote extraído acima
        {
            TYPE_IPV4: ipv4; // se o valor de etherType for igual a 0x800 (indicando que o protocolo encapsulado é IPv4), o parser transita para o estado ipv4, abaixo
            default: accept; // caso o valor de etherType não seja 0x800, o parser transita para o estado accept, o que significa que o pacote não será processado mais
        }
    }

    // estado ipv4
    state ipv4 {
        packet.extract(hdr.ipv4); // extrai o cabeçalho ipv4 do pacote para acessar as informações contidas no pacote
        transition accept; // depois de extraídas as informações, o pacote está pronto para seguir para as próximas fases do código
    }

}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

// verificação de integridade do checksum
// não implementado nesse código
control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

// processamento dos pacotes
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    
    // ação de descartar o pacote
    action drop() {
        mark_to_drop(standard_metadata); // marca o pacote para ser descartado
    }

    // ação de encaminhar o pacote ipv4
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        // o novo mac de origem recebe o mac de destino anterior
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        // o novo mac de destino recebe o mac do próximo dispositivo (tabela de encaminhamento)
        hdr.ethernet.dstAddr = dstAddr;
        // define a porta de do switch para qual o pacote deve ser encaminhado (tabela de encaminhamento)
        standard_metadata.egress_spec = port;
        // decrementar o ttl em 1
        hdr.ipv4.ttl = hdr.ipv4.ttl -1;
    }

    // A tabela ipv4_lpm - "Longest Prefix Match" (LPM), ela verifica o endereço de destino IPv4 do pacote e busca na tabela de encaminhamento uma correspondência mais longa (prefixo) para encaminhar o pacote
    table ipv4_lpm {
        key = { 
            hdr.ipv4.dstAddr: exact; // chave para encontrar a correspondência na tabela de encaminhamento
        }
        // ações que podem ser realizadas
        actions = {
            ipv4_forward; // encaminhar o pacote
            drop; // descartar o pacote
            NoAction; // se não for encontrada nenhuma ação específica para o pacote, ele não será alterado
        }
        size = 1024; // se refere ao tamanho máximo de entradas que a tabela pode ter
        default_action = NoAction(); // define a ação padrão
    }

    // aplicar determinadas ações
    apply {
        // método que verifica se o pacote IPv4 foi extraído corretamente e está válido e se o protocolo é do tipo TCP
        if (hdr.ipv4.isValid() && hdr.ipv4.protocol == PROTOCOL_TCP) {
            // se TCP, aplique a tabela de roteamento
            ipv4_lpm.apply();
        } else {
            // se não for TCP, drop o pacote
            drop();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

// assim como o ingress, acima, faz o processamento dos pacotes na entrada, aqui seria o caso de algum processo ser realizado no pacote antes da saída
// não implementado nesse código
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A Ç Ã O   ***************
*************************************************************************/

// novo cálculo de verificação de integridade do checksum
control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

// basicamente, é reconstruir todo o pacote o pacote ipv4 e frame ethernet
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet); // packet.emit() => reconstrói e envia o pacote para a saída
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//pipeline de execução definida para a arquitetura do V1Switch
V1Switch(
    MyParser(), // realiza a análise do pacote
    MyVerifyChecksum(), // verifica a integridade do checksum
    MyIngress(), // processamento de entrada no pacote
    MyEgress(), // processamento de saída no pacote
    MyComputeChecksum(), // recalcula o checksum
    MyDeparser() // reconstrói e envia o pacote
) main;