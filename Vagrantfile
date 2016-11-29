# =====================================================================
#        File:  Vagrant
#     Project:  vagrant-gluster-demo
#    Location:  vagrant-gluster-demo/Vagrant
#   Launguage:  Ruby
#    Category:  Storage
#     Purpose:  Setup Gluster Management and Storage Nodes
#      Author:  Sacha Dubois
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# =====================================================================
# 08.08.2016  Sacha Dubois  new
# =====================================================================
# References: 
# https://atlas.hashicorp.com/centos/boxes/7

require 'fileutils'
require './vagrant-provision-reboot-plugin'

# Some variables we need below
VAGRANT_ROOT = File.dirname(File.expand_path(__FILE__))

numberOfVMs = 0
numberOfDisks = -1
HOSTNAME = Socket.gethostname
CONFDIR = 'config/' + HOSTNAME + '/'

#################
# General VM settings applied to all VMs
#################
VMCPU = 2
VMMEM = '768'
#################

if ARGV[0] == "up"
  FileUtils.mkdir_p CONFDIR
  environment = open(CONFDIR + 'vagrant_env.conf', 'w')

  numberOfVMs = 4
  numberOfDisks = 4
  provisionEnvironment = true

  print "All gluster configuration demos can be demonstrated with 4 gluster nodes\n"
  print "expect Gluster Dispersed Volumes which requires 6 Nodes\n"
  print "=> 4 Node + Mgmt = 3840 MB RAM\n"
  print "=> 6 Node + Mgmt = 5376 MB RAM\n"
  print "\n"

  while true
    print "Do you want to greate 4 or 6 Gluster Nodes ? (Default 4): "
    answer = $stdin.gets.strip.to_s.downcase
    if answer == "" or answer == "n" or answer == "no"
      provisionEnvironment = false
      break
    elsif answer == "4"
      numberOfVMs = 4
      break
    elsif answer == "6"
      numberOfVMs = 6
      break
    end
  end
  
  environment.puts("# BEWARE: Do NOT modify ANY settings in here or your vagrant environment will be messed up")
  environment.puts(numberOfVMs.to_s)
  environment.puts(numberOfDisks.to_s)

  print "Vagrant will no set up the Mgmt Node (rhgs-mgmt) and #{numberOfVMs} Gluster nodes with #{numberOfDisks} disks each\n\n"

  system "sleep 1"
else 
  environment = open(CONFDIR + 'vagrant_env.conf', 'r')
  environment.readline # Skip the comment on top
  numberOfVMs = environment.readline.to_i
  numberOfDisks = environment.readline.to_i

  #if ARGV[0] != "ssh-config"
  #  puts "Detected settings from previous vagrant up:"
  #  puts "  We deployed #{numberOfVMs} nodes each with #{numberOfDisks} disks"
  #  puts ""
  #end
end

environment.close

diskNames = ['sda', 'sdb', 'sdc', 'sdd', 'sde']

hostsFile = "192.168.15.100 rhgs-mgmt\n"
hostsList = "rhgs-mgmt\n"
(1..numberOfVMs).each do |num|
  hostsFile += "192.168.15.#{( 100 + num).to_s} rhgs-0#{num.to_s}\n"
  hostsList += "rhgs-0#{num.to_s}"
end

def vBoxAttachDisks(numDisk, provider, boxName)
  provider.customize ["storagectl", :id, "--add", "sata", "--name", "SATA" , "--portcount", 2, "--hostiocache", "on"]
  for i in 1..numDisk.to_i
    file_to_disk = File.join(VAGRANT_ROOT, CONFDIR + 'disks', ( boxName + '-' +'disk' + i.to_s + '.vdi' ))
    unless File.exist?(file_to_disk)
      provider.customize ['createhd', '--filename', file_to_disk, '--size', 100 * 1024] # 30GB brick device
    end
    provider.customize ['storageattach', :id, '--storagectl', 'SATA', '--port', i, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]
  end
end

def lvAttachDisks(numDisk, provider)
  for i in 1..numDisk.to_i
    provider.storage :file, :size => '100G'
  end
end

# Vagrant config section starts here
Vagrant.configure(2) do |config|
 
  numberOfVMs.downto(1) do |vmNum|

    config.vm.synced_folder "scripts/", "/vagrant", type: "nfs"
    #config.vm.synced_folder "scripts/", "/vagrant"

    config.vm.define "rhgs-0#{vmNum.to_s}" do |copycat|
      # This will be the private VM-only network where GlusterFS traffic will flow
      copycat.vm.network "private_network", ip: ( "192.168.15." + (100 + vmNum).to_s )
      copycat.vm.hostname = "rhgs-0#{vmNum.to_s}"

      copycat.vm.provider "virtualbox" do |vb, override|
        override.vm.box = "centos/7"
        config.ssh.insert_key = false

        # Don't display the VirtualBox GUI when booting the machine
        vb.gui = false
        vb.name = "rhgs-0#{vmNum.to_s}"
      
        # Customize the amount of memory and vCPU in the VM:
        vb.memory = VMMEM
        vb.cpus = VMCPU

        system "sleep 10"
        vBoxAttachDisks( numberOfDisks, vb, "rhgs-0#{vmNum.to_s}" )
      end

      copycat.vm.provider "libvirt" do |lv, override|
        override.vm.box = "centos/7"
	#gaga
        config.ssh.insert_key = false
      
        # Customize the amount of memory and vCPU in the VM:
        lv.memory = VMMEM
        lv.cpus = VMCPU
        lv.graphics_type = 'spice'

        system "sleep 10"
        lvAttachDisks( numberOfDisks, lv )
      end

      # --- INSTALL GLUSTER ---
      command =  "sudo yum update -y;"
      command += "sudo yum install wget -y;"
      command += "sudo wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-8.noarch.rpm;"
      command += "sudo rpm -ivh epel-release-7-8.noarch.rpm;"
      command += "sudo yum install centos-release-gluster -y;"
      command += "sudo yum install glusterfs-server cifs-utils samba-vfs-glusterfs samba-client -y;"
      command += "sudo yum install samba samba-client samba-common samba-vfs-glusterfs selinux-policy-targeted -y;"
      command += "sudo yum install nfs-ganesha-gluster glusterfs-ganesha -y;"
      command += "sudo systemctl start glusterd.service;"
      command += "sudo systemctl enable glusterd.service;"
      copycat.vm.provision "shell", inline: command

      # --- CONFIGURE SAMBA ---
      copycat.vm.provision "shell", inline: <<-SHELL
      echo "[gluster-gvol]\n\
comment = SMB share for GlusterFS volume gvol\n\
vfs objects = glusterfs\n\
glusterfs:volume = gvol\n\
glusterfs:logfile = /var/log/samba/glusterfs-gvol.%M.log\n\
glusterfs:loglevel = 7\n\
path = /\n\
read only = no\n\
guest ok = yes" | sudo tee /etc/samba/smb.conf

      sudo setsebool -P samba_share_fusefs on
      sudo setsebool -P samba_load_libgfapi on
      sudo systemctl start smb.service
      sudo systemctl enable smb.service
      sudo systemctl start nmb.service
      sudo systemctl enable nmb.service
  SHELL

      # --- ACTIONS TO BE DONE ON FIRST NODE ---
      if copycat.vm.hostname == "rhgs-01"
        command =  'cd /;'

        # If the user wishes no automatic deployment -> Forget the previous steps
        if provisionEnvironment
          puts "Skipping automated gluster deployment"
          command = ''
        else
          copycat.vm.provision "shell", inline: command

          if ARGV[0] == "up1"
            puts "# ACCESS_KEY and SECRET_KEY to connect RadowsGW"
            puts "# accesible within the guest on /vagrant/#{CONFDIR}env_gluster or"
            puts "from the host by #{CONFDIR}env_gluster"
     
            if File.exist?("#{CONFDIR}env_gluster")
              file = File.new("#{CONFDIR}env_gluster", "r")
              while (line = file.gets)
                  puts "#{line}"
              end
              file.close
            end
          end
        end


      end

    end
  end

  # MGMT Node
  config.vm.define "rhgs-mgmt" do |mainbox|
  mainbox.vm.network "private_network", ip: '192.168.15.100'
  mainbox.vm.hostname = 'rhgs-mgmt'

    config.vm.synced_folder "scripts/", "/vagrant", type: "nfs"
    #config.vm.synced_folder "scripts/", "/vagrant"

    mainbox.vm.provider "virtualbox" do |vb, override|
      override.vm.box = "centos/7"

      # Don't display the VirtualBox GUI when booting the machine
      vb.gui = false
      vb.name = "rhgs-mgmt"

      # Customize the amount of memory and vCPU in the VM:
      vb.memory = VMMEM
      vb.cpus = VMCPU

      #vBoxAttachDisks( numberOfDisks, vb, 'MON' )
    end

    mainbox.vm.provider "libvirt" do |lv, override|
      override.vm.box = "centos/7"

      # Customize the amount of memory and vCPU in the VM:
      lv.memory = VMMEM
      lv.cpus = VMCPU

      #lvAttachDisks( numberOfDisks, lv )
    end

    command = 'cd /;'
    command += 'cd /;'
    mainbox.vm.provision "shell",
      inline: command
  end
  
  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.

  # The flow is outside->in so that this will run before all node specific Shell skripts mentioned above!

  config.vm.provision "shell", inline: <<-SHELL
    mkdir -p /root/.ssh;
    echo '#{hostsFile}' | sudo tee -a /etc/hosts
echo "-----BEGIN RSA PRIVATE KEY-----\n\
MIIEpQIBAAKCAQEAv0MEkWqd38GO/UqagCbr0cL6SEBC9p4gwVRRrOiDN/E8yx2x\n\
AZ8EapWBY7KiHUaw9Rp3HKuWtOmabtpmutu1vKigd9y3aMyprY0Qemi1RbbhihWQ\n\
ULQw1RiL/3g2ZdveUMeLogkjBEnVvoRPkDxMNB9WvTczQdiwwSDnyXtRNIXlukcX\n\
SrSAwNzdnuroU51OI0HUOMvN6BWm4A1REFsaLLuquNas/CM0TqBHTtkV5ZFkIRXb\n\
Hm7LeqeSMZUTGTCfF7pZ5yzEoxoPjy5cRULsnTydED5IpZcwDXTvZ9ZWdi6ekf0v\n\
LDOmTyG2uCqmOAO/pTXNrreVK3Q9wQAy0BJNewIDAQABAoIBAQCo6m9mXlr/+tpm\n\
KTU6aSVsJF8W4GpDlHQpSma35sG87nlaieaCIAaue0vC2UkDwiMW1UDNOV3oeUfD\n\
D3AbJ1/iNqtCMNRq4hYZCLS85yzxXQrkARdrrzhRe1RpU6n3W6+EeDeB67/ZUbxM\n\
fl4mbJqAjgz1H4NNbCru5jjPYPHfB7txCvsQEESB2aG1snz4ZfUXHSPRDjz3IoDz\n\
2l9rO6Z3l7tCoM+HdDdKZswU6pyHhJw+3HZN8z57UyKH9JoQTEtas1M+mFFly4FV\n\
HMyvHLZZjFGJJhpQIU5Xh7yoli1oFQwUC6aQ/wAHshQhlBLphc3Hb6ZhZpRP0LGd\n\
y6oXmedBAoGBAOBEYcxYCV4hxjRkYUyMbIuj9GOWkoJF2+uNKH4T+ipI/yjQxMzl\n\
wW1EuX1JS0WthHxbJmsMHbJs8Og8V8ZwWxMghosOlqR4mIBfon056DrXgoNPhgd6\n\
kQj+vW/WnBs9HmzbV9cDGfhGhQsAXdH8XITIW4msJ9qz7OO8ef+MpSD/AoGBANpT\n\
FdIikCcbFKnwdhCjHyZc1D0EXmLbX08Fowgbbo1eELUqtuUKOpP8f+aGP+2B0fCR\n\
fmZdpDrHydnspSQot7PGzbM9BkqieFP8fwTjMBGHKDNYqIdph+AcGatMyHtqluGH\n\
jTOEnOmyMi9LEMfuH+0jIr2nbUZhbV+vi4IebteFAoGAKjT0au7OpIaatNWHck6j\n\
RwyOPAfkftwC7avdSQ0dccPXMalIwH8lDhl3B1s57V0gp/7HljHrjN7v3+UrZ89R\n\
dKIUcCtIsp93pAFbpVG2oQxaJbhbsyCgFx9KK7gqHP49saL+Pxr4Uj+DXnStM43Z\n\
I6xJffmGbqSaGqooE642jaUCgYEAj9KuDEkSl4Big3TSAjHDYn1Cn5OSLiN/zMnU\n\
1ZFkqaIu9XnXFFlBr51mEFGeKXMc/xKJpxvHBaX5liMrwv9DzR2JAquPynjvNbyf\n\
XHPhhZp45CJimxntFbjNPCiP5aWZEac/YJHa4KSwJLGZs2tuAsTjrPZvqS6jY6Z8\n\
C9LKiBUCgYEA3OMu1Kr2sdCIjQOCkCEd1ZPV1yk9QYmfXqDTqZJkODclzl7jkKSR\n\
uscOYalltYnkd21TZhpUSBYkAkHHzlnbtvDhOgzeOehxBzjelrfnZyVy2VHOjEUq\n\
tlZWjdrBwlQZEdeJu1ohSl7vf8cZLQFSOqG0DOjUI9mQqknV+dYpEis=\n\
-----END RSA PRIVATE KEY-----" | sudo tee /root/.ssh/id_rsa
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/QwSRap3fwY79SpqAJuvRwvpIQEL2niDBVFGs6IM38TzLHbEBnwRqlYFjsqIdRrD1Gnccq5a06Zpu2ma627W8qKB33LdozKmtjRB6aLVFtuGKFZBQtDDVGIv/eDZl295Qx4uiCSMESdW+hE+QPEw0H1a9NzNB2LDBIOfJe1E0heW6RxdKtIDA3N2e6uhTnU4jQdQ4y83oFabgDVEQWxosu6q41qz8IzROoEdO2RXlkWQhFdsebst6p5IxlRMZMJ8XulnnLMSjGg+PLlxFQuydPJ0QPkillzANdO9n1lZ2Lp6R/S8sM6ZPIba4KqY4A7+lNc2ut5UrdD3BADLQEk17 root@rhgs-mgmt" >> /root/.ssh/authorized_keys
    sudo cp /root/.ssh/id_rsa /home/vagrant/.ssh/id_rsa
    sudo chown vagrant:vagrant /home/vagrant/.ssh/id_rsa
    sudo chmod 600 /root/.ssh/id_rsa
    sudo chmod 600 /root/.ssh/authorized_keys
    sudo chmod 600 /home/vagrant/.ssh/id_rsa
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8kEAxQ1MZt0GzwlOVUP+zSP3B3yyTRD0zUiFQYVNoGqVL4X2Urn2wUctgsfBTC7m1UrbOj6l0PQUdDYfYRRrn2ko31LpD+Ih2OGzARFZeYAF58Roi3HW+YNf0n6Uiv+Xcs/qnge2gdPLZ4cNTBwYHc12uM6OS6StBBHeLMxZ4sbxEWNmWY/i2m2vR5oNGaTn/Ow35x1jqgY8jOni+MjY7M3mIFjer28m+1KpSM6xq5EIFUOCChz3c2n2Jeeew5V0uN0aTKxB40pm91owk8q/WYXKBXEINpC+tBvhZ0C+rsBKtsQhpQOwGOkdXeu6SqWHxWZfxtIFtogEyNz2mqkIZ vagrant@rhel7-base" | sudo -u vagrant tee -a /home/vagrant/.ssh/authorized_keys
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/QwSRap3fwY79SpqAJuvRwvpIQEL2niDBVFGs6IM38TzLHbEBnwRqlYFjsqIdRrD1Gnccq5a06Zpu2ma627W8qKB33LdozKmtjRB6aLVFtuGKFZBQtDDVGIv/eDZl295Qx4uiCSMESdW+hE+QPEw0H1a9NzNB2LDBIOfJe1E0heW6RxdKtIDA3N2e6uhTnU4jQdQ4y83oFabgDVEQWxosu6q41qz8IzROoEdO2RXlkWQhFdsebst6p5IxlRMZMJ8XulnnLMSjGg+PLlxFQuydPJ0QPkillzANdO9n1lZ2Lp6R/S8sM6ZPIba4KqY4A7+lNc2ut5UrdD3BADLQEk17 rhgs@rhgs-mgmt" | sudo -u vagrant tee -a /home/vagrant/.ssh/authorized_keys
    sudo chmod 600 /home/vagrant/.ssh/authorized_keys
    echo 'Host *' | sudo tee -a /root/.ssh/config
    echo ' StrictHostKeyChecking no' | sudo tee -a /root/.ssh/config
    echo ' UserKnownHostsFile=/dev/null' | sudo tee -a /root/.ssh/config
    echo 'Host *' | sudo -u vagrant tee -a /home/vagrant/.ssh/config
    echo ' StrictHostKeyChecking no' | sudo -u vagrant tee -a /home/vagrant/.ssh/config
    echo ' UserKnownHostsFile=/dev/null' | sudo -u vagrant tee -a /home/vagrant/.ssh/config
    sudo yum install cifs-utils samba-client -y
    sudo yum install glusterfs glusterfs-fuse attr -y

  SHELL

  config.push.define "local-exec" do |push|

  push.inline = <<-SCRIPT
      rsync -avr --exclude 'disk*' --exclude '.vagrant' --exclude '.DS_Store' --exclude 'ssh_conf' --exclude 'vagrant_env.conf' . storchris.dorf.rwth-aachen.de:/var/www/vagrant/RHCS-RHEL7/
    SCRIPT
  end



end
