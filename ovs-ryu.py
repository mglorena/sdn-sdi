from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.link import TCLink
from mininet.log import setLogLevel
from mininet.cli import CLI



def run():
    net = Mininet(controller=None, switch=OVSSwitch, link=TCLink,
                  autoSetMacs=True, autoStaticArp=True)

    # Switch OVS
    s1 = net.addSwitch('s1')

    # Se indica que se usará un Controlador remoto, dentro del host local
    c0 = net.addController('c0', controller=RemoteController,
                           ip='127.0.0.1', port=6653)

    # Hosts
    h1 = net.addHost('h1', ip='10.0.0.1/24')
    h2 = net.addHost('h2', ip='10.0.0.2/24')
    h3 = net.addHost('h3', ip='10.0.0.3/24')

    # Enlaces
 net.addLink(h1, s1, bw=100, delay='2ms', max_queue_size=100)
 net.addLink(h2, s1, bw=100, delay='2ms', max_queue_size=100)
 net.addLink(h3, s1, bw=100, delay='2ms', max_queue_size=100)
    net.start()
    # Servicios qeu sirven para testear
    h2.cmd('python3 -m http.server 80 &')
    h3.cmd('python3 -m http.server 80 &')
    h2.cmd('iperf3 -s -D')
    h3.cmd('iperf3 -s -D')

    print("Listo: usa `h1 iperf3 -c 10.0.0.2 -t 10 -i 1` y `h1 curl http://10.0.0.2/`")
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    run()
