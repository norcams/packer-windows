os_name                 = "windows"
os_version              = "2019"
os_arch                 = "x86_64"
is_windows              = true
iso_url                 = "https://software-static.download.prss.microsoft.com/pr/download/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso"
iso_checksum            = "549bca46c055157291be6c22a3aaaed8330e78ef4382c99ee82c896426a1cee1"
parallels_guest_os_type = "win-2019"
vbox_guest_os_type      = "Windows2019_64"
vmware_guest_os_type    = "windows9srv-64"
qemu_efi                = true
local_iso               = "e713134d34c0e6b17c2bb255d974420ddabd776d.iso"
boot_wait               = "2s"
boot_command            = ["aaaaaaa<wait><enter>"]
vnc_bind_address        = "0.0.0.0"
vnc_port_min            = "5998"
vnc_port_max            = "5999"
