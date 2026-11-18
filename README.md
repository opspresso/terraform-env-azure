# terraform-env-azure

Azure 테넌트 Clush(`b84c843a-4ece-4ef7-8788-372e1f232c0a`)의 구독 `Azure subscription 1`(`ce097188-9b76-44f9-8bbd-366ae73ade04`, `koreacentral`) 리소스를 관리합니다.
이 구독은 Agent Runway 환경 `dmz`의 앱을 Azure VM scale set(`vmss` target)으로 실행합니다.
Agent Runway와 그 설치 계정 opspresso(`396608815058`)의 리소스는 [terraform-env-opsp](https://github.com/opspresso/terraform-env-opsp)가 관리합니다.
`dmz/`의 각 디렉터리는 독립된 Terraform root입니다.

| 디렉터리 | 용도 |
| --- | --- |
| [3-domain](dmz/3-domain/README.md) | Azure DNS zone `dmz.rovr.dev`. opspresso `rovr.dev`가 위임한다 |
| [8-runway-target](dmz/8-runway-target/README.md) | Agent Runway 계정 `clush-azure`와 환경 `dmz`의 `vmss` target: VNet·subnet, Variable Key Vault, bundle Storage, Front Door profile, Entra 앱 2개(federated credential)와 역할 |
| [8-forge-desktop](dmz/8-forge-desktop/README.md) | Agent Forge 개발자 데스크톱 기반: VNet·NAT Gateway, AVD workspace·개인 host pool·app group·scaling plan, Compute Gallery, Azure Policy, 그룹 `DevDesktop-Users`, Entra 앱 `agent-forge-desktop`(federated credential)과 역할 |

`images/`에는 Packer 이미지 template이 있습니다. [dev-desktop-win10](images/dev-desktop-win10/README.md)은 `8-forge-desktop`의 gallery에 Windows 10 개발자 데스크톱 이미지를 게시합니다.

처음 적용할 때의 순서는 다음과 같습니다.

1. `3-domain`
2. terraform-env-opsp `demo/8-app-delivery`: `dmz.rovr.dev` NS 위임(`3-domain`의 `name_servers`)
3. `8-runway-target`
4. Agent Runway 계정 `clush-azure` 추가, 접근 확인, 환경 `dmz`에 `vmss` target 추가
5. `8-forge-desktop`
6. `images/dev-desktop-win10`: 이미지 버전 게시
7. Agent Forge 데스크톱 풀에 `8-forge-desktop` 출력 입력

## 디렉터리 이름

root는 `dmz/<NN>-<주제>`입니다. `dmz`는 이 구독을 쓰는 Agent Runway 환경 이름입니다.
번호는 terraform-env-demo·terraform-env-opsp와 같은 의존 순서를 따릅니다: `3` DNS, `8` 서비스별 리소스. 번호가 작은 root를 먼저 적용합니다.
구독 기본 설정(`1`)과 공유 네트워크(`2`) root는 없습니다. 네트워크는 `8-runway-target`과 `8-forge-desktop`이 각자 만듭니다.

## 준비와 실행

Terraform `1.17.1`과 Azure CLI가 필요합니다. 적용하는 사용자는 구독의 Owner(또는 Contributor와 Role Based Access Control Administrator)여야 하고,
`8-runway-target`·`8-forge-desktop`의 Entra 앱을 만들려면 테넌트에서 앱 등록 권한이, `8-forge-desktop`의 보안 그룹을 만들려면 그룹 생성 권한이 있어야 합니다. provider는 Azure CLI 로그인을 씁니다.
provider와 backend는 `subscription_id`를 정하므로 CLI의 기본 구독과 관계없이 이 구독에서만 동작합니다.

```bash
az login --tenant b84c843a-4ece-4ef7-8788-372e1f232c0a
cd dmz/<root>
terraform init
terraform fmt -check
terraform validate
terraform plan
```

plan에서 예상한 변경만 있는지 확인한 뒤 `terraform apply`를 실행합니다. Azure 리소스나 데이터를 삭제하기 전에는 영향을 별도로 확인합니다.

state는 이 구독의 Storage account `tfstatece097188`(리소스 그룹 `rg-terraform-state`) container `tfstate`에 `dmz/<이름>-dmz.tfstate`로 저장합니다(예: `dmz/forge-desktop-dmz.tfstate`).
Storage account는 Terraform 밖에서 Azure CLI로 만들었습니다. shared key를 끄고 blob versioning과 30일 삭제 보존을 켰습니다.
backend는 Entra 인증(`use_azuread_auth = true`)을 쓰므로 state를 읽고 쓰려면 그 Storage account의 `Storage Blob Data Contributor`가 필요합니다.
잠금은 blob lease입니다. backend key는 임의로 바꾸지 마세요.

## 구독 형식

Azure Front Door는 Free Trial 구독에서 만들 수 없습니다(`Free Trial and Student account is forbidden for Azure Frontdoor resources`).
`8-runway-target`을 적용하려면 구독이 종량제(Pay-As-You-Go) 이상이어야 합니다.

VM 크기는 vCPU quota가 있는 family에서 고릅니다. `koreacentral`의 지역 vCPU 한도는 10이고, B-series v2(`standardBsv2Family`·`standardBasv2Family`)의
family 한도는 0입니다. 그래서 `Standard_B2s_v2`는 `QuotaExceeded`로 배포되지 않습니다. Agent Runway 환경 `dmz`의 `sizes`에는 amd64 `Standard_D2s_v6`(Dsv6),
arm64 `Standard_D2ps_v7`(Dpsv7)처럼 한도가 있는 family를 씁니다. 지역 한도는 앱 instance 수와 rollout에 필요한 여유 instance를 함께 제한합니다.
한도는 다음 명령으로 확인하고, 더 필요하면 포털 **할당량**에서 요청합니다.

```bash
az vm list-usage --location koreacentral -o table
```

## Terraform 작성 규칙

`dmz/`의 모든 root는 같은 파일 배치와 작성 규칙을 따릅니다. 규칙은 terraform-env-opsp·terraform-env-two와 같고, AWS 전용 규칙 대신 Azure 규칙을 씁니다.
`scripts/check-layout.sh`가 파일 배치를 검사하고, CI가 이 스크립트와 `terraform fmt -check`·`terraform validate`를 실행합니다.

### 파일 이름

파일 이름은 `NN-<주제>.tf`입니다. `NN`은 두 자리 숫자이고, 주제는 소문자·숫자·`-`로 씁니다.

| 파일 | 담는 블록 |
| --- | --- |
| `00-variables.tf` | 모든 `variable`. `variable`이 없는 root에는 두지 않습니다 |
| `02-backend.tf` | `terraform`(`required_version`·`backend`·`required_providers`)과 `provider` |
| `02-remote-state.tf` | `data "terraform_remote_state"` |
| `03-data.tf` | 여러 파일이 함께 쓰는 `data` |
| `03-locals.tf` | 여러 파일이 함께 쓰는 `locals`와 태그용 `local.tags` |
| `04-`~`98-<주제>.tf` | 주제별 리소스와 그 주제의 `data`·`locals`. 의존 순서대로 번호를 붙이고, 한 주제를 여러 파일로 나누면 같은 번호를 씁니다 |
| `99-outputs.tf` | 모든 `output` |

각 root에는 `required_version`과 같은 값의 `.terraform-version`을 둡니다.

### 코드

- `required_version`과 provider `version`은 정확한 버전으로 고정합니다(예: `"1.17.1"`, `"5.14.0"`). 범위 지정은 쓰지 않습니다.
- azurerm backend는 `use_azuread_auth = true`를 씁니다.
- azurerm provider는 `subscription_id = var.subscription_id`로 구독을 정합니다. azurerm에는 기본 태그가 없으므로 태그를 받는 리소스마다 `tags = local.tags`를 씁니다.
- `variable`에는 `description`과 `type`을 씁니다.
- 파일마다 `locals` 블록은 하나만 둡니다. 본문이 없는 블록은 `data "azurerm_client_config" "current" {}`처럼 한 줄로 씁니다.
- 주석은 코드만으로 알 수 없는 이유·제약·외부 연결을 설명합니다. 파일 이름이나 블록 종류를 반복하는 머리 주석은 쓰지 않습니다.
- 리소스 이름을 바꾸거나 module로 옮길 때는 `moved` 블록을 함께 씁니다.
- 공개 저장소입니다. 비밀 값은 커밋하지 않습니다. 이 저장소의 root는 비밀 값을 쓰지 않습니다.
