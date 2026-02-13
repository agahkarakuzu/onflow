# onflow

![](misc/bids2nf.svg)

Optic nerve analysis pipeline built on [bids2nf](https://github.com/agahkarakuzu/bids2nf).

## Quick Start

```bash
nextflow run main.nf --bids_dir YOUR/BIDS/DIR -profile arm64
```

## Configuration Management

All pipeline configurations are managed in the [config/](config/) directory:

- **[config/bids2nf/onflow.yaml](config/bids2nf/onflow.yaml)** - bids2nf configuration for onflow
  - Define imaging modalities (`T1w`, `DWI`, `derivatives`)
  - Specify looping entities (`sub`, `ses`, `run`)
  - For more, see https://agah.dev/bids2nf/configuration

- **[config/nf_base.config](config/nf_base.config)** - Base Nextflow settings

- **[config/nf_registration.config](config/nf_registration.config)** - Registration pipeline parameters

- **[config/profiles/](config/profiles/)** - Platform-specific profiles (arm64, amd64)

### Editing Configurations

1. **To modify BIDS dataset specifications**: Edit [config/bids2nf/onflow.yaml](config/bids2nf/onflow.yaml)
2. **To adjust Nextflow parameters**: Edit [config/nf_base.config](config/nf_base.config) or [config/nf_registration.config](config/nf_registration.config)
3. **To change platform settings**: Edit files in [config/profiles/](config/profiles/)

## Submodule Structure

**⚠️ IMPORTANT: Do not modify anything inside the [bids2nf/](bids2nf/) directory.**

This repository uses git submodules:

```
onflow/
├── bids2nf/                    # Submodule (DO NOT MODIFY)
│   └── libBIDS.sh/            # Nested submodule (DO NOT MODIFY)
└── config/
    └── bids2nf/
        └── onflow.yaml        # Your custom bids2nf config
```

- **[bids2nf](https://github.com/agahkarakuzu/bids2nf)** is a git submodule providing BIDS parsing functionality
- **libBIDS.sh** is a nested submodule within bids2nf
- All customization happens in [config/bids2nf/onflow.yaml](config/bids2nf/onflow.yaml), never in the submodule itself

### Updating Submodules

```bash
# Initialize submodules after cloning
git submodule update --init --recursive

# Update to latest submodule versions
git submodule update --remote --recursive
```