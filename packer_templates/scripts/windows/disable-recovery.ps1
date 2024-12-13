# By default Server 2025 and later insist on creating a recovery partition after the system partition
# instead of accepting the system32/recovery location. We need to delete this partition in order to
# allow the system drive to expand when deploying to OpenStack.
if ($winbuild -ge 26100) {
  Write-Host 'Delete the recovery partition'
  reagentc /disable
  Remove-Partition -DiskNumber 0 -PartitionNumber 4 -Confirm:$false
}
