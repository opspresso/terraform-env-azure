# dev-desktop-win10

Agent Forge 개발자 데스크톱의 Windows 10 이미지를 Packer로 빌드해 Compute Gallery 이미지 정의 `galforgedesktopdmz/dev-desktop-win10`에 게시합니다.
이미지 정의는 [`dmz/8-forge-desktop`](../../dmz/8-forge-desktop/README.md)이 만듭니다. 설계는 agent-platform `docs/DEV_DESKTOP.md`의 "데스크톱 이미지"입니다.

## 이미지 내용

| 층 | 내용 |
| --- | --- |
| OS | `MicrosoftWindowsDesktop:Windows-10:win10-22h2-ent-g2:latest`(Windows 10 Enterprise 22H2 single-session, Gen2)와 빌드 시점의 Windows Update(Preview 제외) |
| 개발 도구 | Git for Windows, VS Code(system installer), Node.js LTS(MSI), Python 3(all users). 모두 machine-wide로 설치하고 machine `PATH`에 둔다 |
| 코딩 CLI | `@anthropic-ai/claude-code`, `@openai/codex`, `opencode-ai`. npm으로 `C:\Program Files\npm-global`에 설치하고 그 디렉터리를 machine `PATH`에 더한다 |
| ESU | `EnableESUSubscriptionCheck = 1`([ESU](#esu)) |
| 일반화 | sysprep `/oobe /generalize /mode:vm`. 어디에도 가입하지 않은 상태로 게시한다 |

버전은 `dev-desktop-win10.pkr.hcl`의 변수 `tools` 한 곳에서 정합니다. 설치 파일마다 배포처가 공개한 SHA-256을 함께 고정하고, 빌드는 다운로드한 파일의 SHA-256이 다르면 실패합니다.

| 도구 | 버전 | SHA-256 출처 |
| --- | --- | --- |
| Git for Windows | `2.56.1` | GitHub release asset digest |
| VS Code | `1.146.0` | `update.code.visualstudio.com` API의 `sha256hash` |
| Node.js | `26.13.1`(LTS) | `nodejs.org/dist/v26.13.1/SHASUMS256.txt` |
| Python | `3.15.2` | python.org release file API의 `sha256_sum` |
| Claude Code | `2.1.327` | npm registry integrity |
| Codex CLI | `0.170.0` | npm registry integrity |
| opencode | `1.19.6` | npm registry integrity |

코딩 CLI 디렉터리는 관리자만 바꿀 수 있습니다. 그래서 일반 사용자의 CLI 자동 업데이트는 그 디렉터리에 쓰지 못합니다. 버전을 올리려면 `tools`를 바꾸고 새 이미지 버전을 게시합니다.
사용자가 직접 실행하는 `npm install -g`는 사용자 디렉터리(`%APPDATA%\npm`)에 설치됩니다.

빌드 사용자 `pkrbuild`는 sysprep 뒤에도 남습니다. 그래서 `C:\Windows\Setup\Scripts\SetupComplete.cmd`가 첫 부팅 때 그 계정과 profile을 지웁니다. 데스크톱의 admin 사용자 이름으로 `pkrbuild`를 쓰지 마세요.

## ESU

Windows 10 지원은 2025-10-14에 끝났습니다. Azure Virtual Desktop session host는 ESU를 추가 비용 없이 받습니다.

- Microsoft Learn [Understanding Extended Security Updates (ESU) for Windows 10: Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/understanding-extended-security-updates)의
  "3. Administration, Policy & Opt-In Controls"는 ESU 정책을 명시적으로 켜야 한다고 하고, 정책으로 다음 문서를 가리킵니다.
- [Enable Windows 10 Extended Security Updates (ESU) for clients accessing cloud and virtual machines](https://learn.microsoft.com/windows/whats-new/enable-extended-security-updates-virtual)의 정책은
  Licensing CSP `./Device/Vendor/MSFT/Policy/Config/Licensing/EnableESUSubscriptionCheck`(Integer `1`)이고, registry 값은
  `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform\ESU`의 `EnableESUSubscriptionCheck`(REG_DWORD `1`)입니다.
  `scripts/enable-esu.ps1`이 이 값을 씁니다.
- 같은 문서의 전제 조건은 KB5066791 이후 업데이트와 ESU Licensing Preparation Package KB5072653입니다. 빌드의 Windows Update 단계가 설치합니다.
- 같은 문서는 Azure Virtual Desktop을 "No additional configuration or keys are needed" 환경으로도 적습니다. 두 문서가 다르므로, 정책 값을 켜 두는 쪽을 택했습니다. 이 값은 ESU 키를 설치하지 않습니다.

빌드 로그의 `verify.ps1` 출력에서 OS build(`19045.<UBR>`)와 정책 값을 확인합니다. UBR이 source 이미지보다 크면 지원 종료 뒤의 ESU 누적 업데이트를 받은 것입니다.

## 준비

- Packer `1.16.2`(`brew tap hashicorp/tap && brew install hashicorp/tap/packer`)와 Azure CLI 로그인이 필요합니다. Packer는 Azure CLI 인증(`use_azure_cli_auth`)을 씁니다.
- 실행하는 사용자는 구독에서 리소스 그룹을 만들고 지울 수 있어야 하고(Contributor 이상), 이미지 정의에 버전을 쓸 수 있어야 합니다.
- 빌드 VM은 `Standard_D4s_v6`(Dsv6 family, vCPU 4)입니다. `koreacentral`의 지역·family vCPU 한도에 4개의 여유가 있어야 합니다.
- 빌드 VM의 WinRM(5986)은 `allowed_inbound_ip`에서만 열립니다. Packer를 실행하는 기기의 공인 IP를 넣습니다.

## 빌드와 게시

```bash
cd images/dev-desktop-win10
packer init .
packer validate -var image_version=1.0.1 -var allowed_inbound_ip=$(curl -s https://ifconfig.me) .
packer build -var image_version=1.0.1 -var allowed_inbound_ip=$(curl -s https://ifconfig.me) .
```

- 이미지 버전은 빌드마다 새 값을 씁니다. 게시한 버전은 바꾸지 않습니다. 복제본은 `koreacentral` 1개, 저장소는 `Standard_LRS`입니다.
- 빌드는 1~2시간 걸립니다. 대부분 Windows Update 시간입니다.
- Packer는 임시 리소스 그룹 `pkr-Resource-Group-<random>`(VM·디스크·NIC·공인 IP·VNet·WinRM 인증서용 Key Vault)을 만들고 빌드가 끝나거나 실패하면 지웁니다.
  `Ctrl+C`로 멈추면 Packer가 정리합니다. 프로세스가 강제로 끝났으면 `az group list --query "[?starts_with(name,'pkr-Resource-Group-')].name"`으로 남은 그룹을 찾아 지웁니다.
  임시 Key Vault는 soft delete 상태로 남을 수 있습니다. `az keyvault list-deleted --query "[?starts_with(name,'pkrkv')].name"`으로 확인하고 `az keyvault purge --name <이름>`으로 지웁니다.

## 게시 후 시험

게시한 버전으로 시험 VM 하나를 임시 리소스 그룹에 만들고, run command(SYSTEM, machine `PATH`)로 도구를 실행한 뒤 리소스 그룹을 지웁니다.

```bash
image=$(az sig image-version show -g rg-forge-desktop-dmz -r galforgedesktopdmz -i dev-desktop-win10 -e 1.0.1 --query id -o tsv)
subnet=$(cd ../../dmz/8-forge-desktop && terraform output -raw subnet_id)
az group create -n rg-forge-desktop-dmz-smoke -l koreacentral
az vm create -g rg-forge-desktop-dmz-smoke -n smoke --image "$image" --size Standard_D2s_v6 \
  --security-type TrustedLaunch --enable-secure-boot true --enable-vtpm true --license-type Windows_Client \
  --subnet "$subnet" --public-ip-address "" --nsg "" --admin-username smokeadmin --admin-password "<임시 비밀번호>"
az vm run-command invoke -g rg-forge-desktop-dmz-smoke -n smoke --command-id RunPowerShellScript \
  --scripts 'foreach ($c in "git --version","code --version","node --version","python --version","claude --version","codex --version","opencode --version") { cmd /d /c "$c 2>&1" }'
az group delete -n rg-forge-desktop-dmz-smoke --yes
```

`az vm create`가 Dsv6에 맞는 `diskControllerType`을 고르지 못하면 ARM template으로 `NVMe`를 지정합니다. 임시 비밀번호는 기록하지 않고, 리소스 그룹을 지우면 함께 사라집니다.
