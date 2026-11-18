packer {
  required_version = "1.16.2"

  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "= 2.6.5"
    }
    # Installs Windows updates from a scheduled task: the Windows Update API refuses downloads over WinRM.
    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = "= 0.18.5"
    }
  }
}

variable "subscription_id" {
  description = "The subscription of the gallery (terraform-env-azure dmz/8-forge-desktop)."
  type        = string
  default     = "ce097188-9b76-44f9-8bbd-366ae73ade04"
}

variable "location" {
  description = "The build location and the only replica region."
  type        = string
  default     = "koreacentral"
}

variable "image_version" {
  description = "The gallery image version to publish. Publish a new version for every build; a version is never replaced."
  type        = string
}

variable "allowed_inbound_ip" {
  description = "The public IP or CIDR of the machine running Packer. Only it reaches the build VM's WinRM port."
  type        = string
}

# Every version the image installs. Change them here only. Each installer is checked against its published SHA-256.
variable "tools" {
  description = "Pinned tool versions, download URLs and SHA-256 digests."
  type = object({
    git    = object({ version = string, url = string, sha256 = string })
    vscode = object({ version = string, url = string, sha256 = string })
    node   = object({ version = string, url = string, sha256 = string })
    python = object({ version = string, url = string, sha256 = string })
    npm    = map(string)
  })
  default = {
    # https://github.com/git-for-windows/git/releases (asset digest)
    git = {
      version = "2.56.1"
      url     = "https://github.com/git-for-windows/git/releases/download/v2.56.1.windows.1/Git-2.56.1-64-bit.exe"
      sha256  = "c330c72e10b408cc39994bfefdb63542b0d93d21699325c3e0bd874af8a5a559"
    }
    # System installer. https://update.code.visualstudio.com/api/update/win32-x64/stable/latest (sha256hash)
    vscode = {
      version = "1.146.0"
      url     = "https://vscode.download.prss.microsoft.com/dbazure/download/stable/69047191fc427f2f92828279aae1d90d8eeda7ab/VSCodeSetup-x64-1.146.0.exe"
      sha256  = "972fcb16d819532a25af8dc1976e1c80508e080bf56eb65bfd6a35eed983a35b"
    }
    # LTS "Lithium". https://nodejs.org/dist/v26.13.1/SHASUMS256.txt
    node = {
      version = "26.13.1"
      url     = "https://nodejs.org/dist/v26.13.1/node-v26.13.1-x64.msi"
      sha256  = "0398ced8446e119478c724d1aa37c5afd6aa1a76fceab12787eb9714c5ed8b45"
    }
    # https://www.python.org/downloads/release/python-3152/ (release file API sha256_sum)
    python = {
      version = "3.15.2"
      url     = "https://www.python.org/ftp/python/3.15.2/python-3.15.2-amd64.exe"
      sha256  = "06e225a228191b0f4d1dcf6905fbb21bf9f6970d13a2ec63137ab9bee76f15aa"
    }
    # Installed with npm into C:\Program Files\npm-global, which is on the machine PATH.
    npm = {
      "@anthropic-ai/claude-code" = "2.1.327"
      "@openai/codex"             = "0.170.0"
      "opencode-ai"               = "1.19.6"
    }
  }
}

source "azure-arm" "win10" {
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id
  location           = var.location

  # Packer creates a temporary resource group pkr-Resource-Group-<random> (VM, disk, NIC, public IP, VNet, Key Vault
  # for the WinRM certificate) and deletes it at the end, also after a failed build.
  vm_size                      = "Standard_D4s_v6"
  disk_controller_type         = "NVMe"
  os_type                      = "Windows"
  image_publisher              = "MicrosoftWindowsDesktop"
  image_offer                  = "Windows-10"
  image_sku                    = "win10-22h2-ent-g2"
  image_version                = "latest"
  license_type                 = "Windows_Client"
  security_type                = "TrustedLaunch"
  secure_boot_enabled          = true
  vtpm_enabled                 = true
  public_ip_sku                = "Standard"
  allowed_inbound_ip_addresses = [var.allowed_inbound_ip]

  communicator   = "winrm"
  winrm_username = "pkrbuild"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "30m"

  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = "rg-forge-desktop-dmz"
    gallery_name         = "galforgedesktopdmz"
    image_name           = "dev-desktop-win10"
    image_version        = var.image_version
    storage_account_type = "Standard_LRS"

    target_region {
      name     = var.location
      replicas = 1
    }
  }
  shared_image_gallery_timeout = "90m"

  azure_tags = {
    ManagedBy = "Packer"
    Project   = "terraform-env-azure/images/dev-desktop-win10"
  }
}

build {
  sources = ["source.azure-arm.win10"]

  provisioner "powershell" {
    script = "${path.root}/scripts/prepare.ps1"
  }

  provisioner "file" {
    content     = jsonencode(var.tools)
    destination = "C:\\Windows\\Temp\\tools.json"
  }

  provisioner "powershell" {
    script = "${path.root}/scripts/install-tools.ps1"
  }

  provisioner "powershell" {
    script = "${path.root}/scripts/enable-esu.ps1"
  }

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
    update_limit = 25
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    script = "${path.root}/scripts/verify.ps1"
  }

  provisioner "powershell" {
    script = "${path.root}/scripts/generalize.ps1"
  }
}
