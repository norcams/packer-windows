# Packer-windows
Packer-windows builds Windows images with QEMU and Packer that can be deployed in an OpenStack Cloud with KVM hypervisors. It is a stripped down version of the [bento](https://github.com/chef/bento) repository (which is used to create Vagrant boxes), and incorperates elements from the [Cloudbase Windows Imaging Tools](https://github.com/cloudbase/windows-imaging-tools), which also builds Windows images, albeit on a Hyper-V host. The end result is KVM compatible UEFI images with virtio drivers and [Cloudbase-init](https://cloudbase.it/cloudbase-init/). The target consumers of the images are users of the [Norwegian Research and Education Cloud](nrec.no). The [NREC end user documentation](https://docs.nrec.no/create-windows-machine.html) describes the end user process.

The build process produces a Windows image updated with the latest updates.

***NOTE:**
It you want to build your own Windows images using this repository, you will want to edit or remove elements in nrec_specifics.ps1. Only Windows Server 2019 Standard and Windows Server 2022 Standard are build and tested by the NREC team.

You must download [the iso image with the Windows drivers for paravirtualized KVM/qemu hardware](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso). You can do this from the command line: `wget -nv -nc https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso -O virtio-win.iso` and place it in the same directory that contains this repository directory.

## Example usage
```bash
PACKER_CACHE_DIR="/home/user/packer-windows/packer_cache/" PACKER_LOG=1 packer build --only=qemu.vm -var-file=os_pkrvars/windows/windows-2022-x86_64.pkrvars.hcl ./packer_templates/
```
Packer will launch a vnc server, which you can use to monitor the build process. One build may take between one and two and a half hours, so please be patient.

## Recommended image settings
When deploying the image to OpenStack glance, there are some image properties that must be set, and some settings that we strongly recommend:

```bash
  hw_disk_bus:         'scsi'        # Strongly recommended
  hw_scsi_model:       'virtio-scsi' # Strongly recommended
  hw_machine_type:     'q35'         # Strongly recommended
  hw_qemu_guest_agent: 'yes'         # Recommended
  hw_firmware_type:    'uefi'        # Must be set, legacy BIOS not supported by image
  os_require_quiesce:  'yes'         # Recommended when using ceph
  os_type:             'windows'     # Greatly improves KVM performance
```

Feedback and contributions are welcome.

## License

```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
