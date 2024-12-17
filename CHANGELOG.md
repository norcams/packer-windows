# Change Log

## [v.1.1.0] (2024-12-13)

- Add support for building Server 2025 images
- Remove Azure Arc Setup (Server 2022 and newer, NREC specifics feature)
- Remove Edge Browser (NREC specifics feature)
- Make install of Firefox more robust (NREC specifics feature)
- Building Server 2019 is no longer tested, but should continue to work

## [v.1.0.2] (2024-02-12)

- Do not purge windows features as many of them are very hard to enable later

## [v.1.0.1] (2023-11-15)

- Remove use of deprecated chef-solo provisioner and cookbooks for windows builds
