## Convert disk to GPT - this assumes hw_machine_type=uefi when launching instance in OpenStack.
## Remove to retain legacy BIOS boot for the created image.
$result = c:\windows\system32\mbr2gpt /convert /allowfullos | Out-String
write-host $result
