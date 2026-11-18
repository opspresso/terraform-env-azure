# 8-forge-desktop

Agent Forge 개발자 데스크톱(Azure Virtual Desktop 개인 host pool)의 기반 리소스입니다. Agent Forge는 AWS 계정 opspresso(`396608815058`)의 `eks-demo`에서 실행됩니다.
설계는 agent-platform `docs/DEV_DESKTOP.md`의 "Azure 자원과 네트워크"·"신원과 권한"이고, 이미지는 [`images/dev-desktop-win10`](../../images/dev-desktop-win10/README.md)이 만듭니다.
이 root는 데스크톱 VM을 만들지 않습니다. 데스크톱마다 VM·NIC·디스크·extension은 Agent Forge가 ARM 배포로 `rg-forge-desktop-dmz-hosts`에 만들고 지웁니다.

| 리소스 | 이름 | 용도 |
| --- | --- | --- |
| 리소스 그룹 | `rg-forge-desktop-dmz` | 아래 공유 리소스 |
| 리소스 그룹 | `rg-forge-desktop-dmz-hosts` | Agent Forge가 만드는 데스크톱 리소스(`desktop_resource_group`). Terraform은 이 안의 리소스를 관리하지 않는다 |
| VNet·subnet | `vnet-forge-desktop-dmz`(`10.41.0.0/16`), `desktops`(`10.41.0.0/24`) | 데스크톱 NIC(`subnet_id`). 기본 outbound 접근이 없다 |
| NSG | `nsg-forge-desktop-dmz-desktops` | inbound를 모두 거부한다(`deny-all-inbound`, 우선순위 4096). 같은 VNet의 다른 데스크톱도 들어올 수 없다. AVD는 reverse connect라 inbound가 필요 없다 |
| NAT Gateway·공인 IP | `ng-forge-desktop-dmz`, `pip-forge-desktop-dmz-egress`(Standard, 고정) | 데스크톱의 유일한 outbound 경로와 출발 IP(`egress_ip`). Forge 데스크톱 gateway는 이 IP에서 온 요청만 받는다 |
| AVD workspace | `vdws-forge-desktop-dmz` | 사용자가 Windows App에서 보는 feed(`workspace_id`) |
| AVD host pool | `vdpool-forge-desktop-dmz` | Personal, 직접 배정(Direct), Start VM on Connect, load balancer Persistent, 기본 app group Desktop(`host_pool_id`). RDP 속성 `targetisaadjoined:i:1;enablerdsaadauth:i:1;`(Entra join session host, Entra 인증) |
| AVD app group | `vdag-forge-desktop-dmz` | Desktop app group(`app_group_id`). workspace에 연결된다 |
| scaling plan | `vdscaling-forge-desktop-dmz`, schedule `always` | 개인 scaling plan. 매일 24시간, 연결이 끊기거나 로그오프한 뒤 60분(`idle_minutes`)이 지나면 VM을 할당 해제한다. 접속하면 켠다. 일정에 따라 켜지 않는다 |
| Compute Gallery·이미지 정의 | `galforgedesktopdmz`, `dev-desktop-win10` | Windows, Generalized, Hyper-V Gen2, x64, trusted launch 지원, NVMe 지원, 가속 네트워킹(`gallery_image_definition_id`). 버전은 Packer가 게시한다 |
| Azure Policy | `forge-desktop-host-pool-personal-direct`(정의: 구독, 할당: `rg-forge-desktop-dmz`) | `hostPoolType`이 Personal이 아니거나 `personalDesktopAssignmentType`이 Direct가 아닌 host pool을 거부한다 |
| Entra 보안 그룹 | `DevDesktop-Users` | 데스크톱에 로그인할 수 있는 사용자(`desktop_users`). 이 테넌트에서는 시험 사용자 `jyyu@clush.ai`만 멤버다 |
| Entra 앱 | `agent-forge-desktop` | Agent Forge의 신원(`forge_client_id`). secret과 인증서가 없다 |
| 테넌트 설정 | `Windows Cloud Login`의 `remoteDesktopSecurityConfiguration` | Microsoft Entra authentication for RDP를 켠다([준비](#준비)) |

scaling plan은 azapi(`Microsoft.DesktopVirtualization/scalingPlans@2024-04-03`)로 만듭니다. azurerm `5.14.0`의 `azurerm_virtual_desktop_scaling_plan`은 pooled scaling plan만 만듭니다.
host pool 등록 token은 Terraform이 관리하지 않습니다. Agent Forge가 갱신합니다. 그래서 token이 state에 남지 않습니다.

## 신원과 권한

자격과 배정을 나눕니다. 자격은 그룹 `DevDesktop-Users`가, 배정은 Agent Forge가 정합니다. Agent Forge는 session host 하나를 신청자의 UPN에 직접 배정합니다.

| 주체 | 범위 | 역할 | 이유 |
| --- | --- | --- | --- |
| `DevDesktop-Users` | app group | `Desktop Virtualization User` | 자기에게 배정된 데스크톱을 본다 |
| `DevDesktop-Users` | `rg-forge-desktop-dmz-hosts` | `Virtual Machine User Login` | Entra join VM에 일반 사용자로 로그인한다 |
| Azure Virtual Desktop(앱 ID `9cdead84-a844-4324-93f2-b2e6bb768d07`) | `rg-forge-desktop-dmz-hosts` | `Desktop Virtualization Power On Contributor` | Start VM on Connect |
| Azure Virtual Desktop | 구독 | `Desktop Virtualization Power On Off Contributor` | 개인 scaling plan. 구독보다 좁은 범위에서는 autoscale이 동작하지 않는다 |
| `agent-forge-desktop` | 아래 표 | 사용자 지정 역할 4개 | 데스크톱 생성·전원·배정·반납 |

`agent-forge-desktop`의 federated credential은 `eks-demo` OIDC issuer가 서명한 service account `system:serviceaccount:agent-forge:agent-forge`의 token(audience `api://AzureADTokenExchange`)을 믿습니다.
Agent Forge에는 Key Vault 권한과 `rg-forge-desktop-dmz-hosts` 밖의 쓰기 권한이 없습니다. 기본 제공 역할 `Virtual Machine Contributor`는 Storage key 조회·백업 vault 쓰기를,
`Desktop Virtualization Host Pool Contributor`는 host pool 삭제를 함께 주므로 쓰지 않습니다.
action은 Agent Forge Azure provider가 보내는 호출과 같습니다. 데스크톱 template은 NIC, VM(OS 디스크는 VM이 암묵적으로 만들므로 `disks/write`가 필요하다),
`AADLoginForWindows` extension, AVD agent를 설치하는 run command(등록 token은 protected parameter)를 만듭니다. 반납은 VM·NIC·디스크를 지웁니다.

| 사용자 지정 역할 | 범위 | action |
| --- | --- | --- |
| `Agent Forge desktop operator (dmz)` | `rg-forge-desktop-dmz-hosts` | `Microsoft.Resources/subscriptions/resourceGroups/read`, `Microsoft.Resources/deployments/{read,write,operations/read,operationstatuses/read}`, `Microsoft.Compute/virtualMachines/{read,write,delete,start/action,deallocate/action,instanceView/read}`, `Microsoft.Compute/virtualMachines/extensions/{read,write}`, `Microsoft.Compute/virtualMachines/runCommands/{read,write}`, `Microsoft.Compute/disks/{read,write,delete}`, `Microsoft.Network/networkInterfaces/{read,write,delete,join/action}` |
| `Agent Forge subnet joiner (dmz)` | subnet `desktops` | `Microsoft.Network/virtualNetworks/subnets/{read,join/action}` |
| `Agent Forge host pool operator (dmz)` | host pool | `Microsoft.DesktopVirtualization/hostpools/{read,write,retrieveRegistrationToken/action}`, `hostpools/sessionhosts/{read,write,delete}`, `hostpools/sessionhosts/usersessions/{read,delete}` |
| `Agent Forge image reader (dmz)` | 이미지 정의 `dev-desktop-win10` | `Microsoft.Compute/galleries/images/read`, `Microsoft.Compute/galleries/images/versions/read` |

`hostpools/write`는 등록 token 갱신에 필요합니다. 이 권한으로 배정 방식도 바꿀 수 있으므로 Azure Policy가 type과 배정 방식의 변경을 거부합니다.
적용 후 다음을 확인했습니다: 등록 token 갱신 PATCH는 허용되고, `personalDesktopAssignmentType`을 `Automatic`으로 바꾸는 PATCH와 Pooled host pool 생성은 `RequestDisallowedByPolicy`로 거부됩니다.
user session 로그오프는 `usersessions/delete`입니다. Entra 기기 객체 삭제(반납)는 Microsoft Graph 권한이 필요하며 이 root는 주지 않습니다.

## 준비

- `Microsoft.DesktopVirtualization` resource provider를 등록합니다(`az provider register -n Microsoft.DesktopVirtualization`). 이 구독은 등록했습니다.
- 적용하는 사용자는 구독 Owner와 테넌트에서 앱 등록·보안 그룹 생성 권한이 필요합니다. 앱·그룹의 owner는 적용한 사용자입니다.
- 사용자는 Windows App에서 Entra 계정·MFA로 로그인합니다(host pool `enablerdsaadauth:i:1`). 그러려면 테넌트에서 Microsoft Entra authentication for RDP가 켜져 있어야 합니다.
  `55-rdp-sign-in.tf`가 service principal `Windows Cloud Login`(`270efc09-cd0d-444b-a71f-39af4910ec45`)의 `remoteDesktopSecurityConfiguration.isRemoteDesktopProtocolEnabled`를 `true`로 바꿉니다
  (Microsoft Learn "Configure single sign-on for Azure Virtual Desktop using Microsoft Entra ID"). 이 리소스를 적용하려면 Entra 역할 **Application Administrator** 또는
  **Cloud Application Administrator**가 필요합니다. 역할이 없으면 Microsoft Graph가 `403 Authorization_RequestDenied`를 돌려주고, 나머지 리소스는 그대로 적용됩니다.
  target device group은 두지 않습니다. 사용자는 새 데스크톱에 처음 접속할 때 연결 허용 대화 상자를 한 번 확인합니다(Entra가 최대 15개 host를 30일 동안 기억한다).
  `terraform destroy`는 이 설정을 끄지 않습니다.
- 사용자에게 AVD 사용 자격 라이선스(예: Microsoft 365 E3/E5, Windows Enterprise E3/E5)가 있어야 합니다.

## 적용 순서

1. 이 디렉터리를 적용합니다.

   ```bash
   terraform init
   terraform plan
   terraform apply
   terraform output
   ```

2. [`images/dev-desktop-win10`](../../images/dev-desktop-win10/README.md)으로 이미지 버전을 게시합니다.
3. Agent Forge 데스크톱 풀에 출력 값(`tenant_id`, `subscription_id`, `location`, `forge_client_id`, `desktop_resource_group`, `subnet_id`, `host_pool_id`,
   `gallery_image_version_id`, `trusted_launch`, `egress_ip`)을 넣습니다. 새 이미지 버전을 쓰려면 `image_version`을 바꾸고 다시 적용합니다.
   `gallery_image_version_id`는 이름으로 만든 값이므로, 그 버전이 gallery에 게시됐는지는 Terraform이 확인하지 않습니다. Agent Forge pod에는 audience `api://AzureADTokenExchange`인 projected service account token이 있어야 합니다.

Agent Forge가 데스크톱을 만들 때 지킬 점:

- VM은 `rg-forge-desktop-dmz-hosts`에, NIC는 subnet `desktops`에 둡니다. public IP를 붙이지 않습니다.
- Dsv6 같은 NVMe 전용 크기에는 `diskControllerType = NVMe`를 씁니다. 이미지는 SCSI와 NVMe를 모두 지원합니다.
- Windows 10 client 이미지이므로 `licenseType = Windows_Client`를 씁니다.
- admin 사용자 이름으로 `pkrbuild`를 쓰지 않습니다. 이미지가 첫 부팅 때 그 계정을 지웁니다.
- system-assigned identity만 씁니다. user-assigned identity를 붙이지 않습니다.
- 이미지 정의의 security type은 `TrustedLaunch`입니다(`trusted_launch = true`). 이 이미지로 만든 VM은 모두 trusted launch(secure boot·vTPM)이고, Agent Forge 풀은 `trustedLaunch = true`여야 합니다. Packer가 trusted launch VM에서 캡처한 버전은 `TrustedLaunchSupported` 정의에 게시되지 않습니다. OS 디스크는 `Premium_LRS`입니다.

## 비용과 위험

- 고정 비용은 NAT Gateway(시간 요금과 처리 데이터 요금)와 Standard 공인 IP, gallery 이미지 버전 저장 요금입니다. AVD workspace·host pool·app group·scaling plan은 요금이 없습니다.
- 데스크톱마다 VM 비용(켜져 있는 동안)과 디스크 비용(항상)이 듭니다. VM 크기는 지역 vCPU 한도와 family 한도 안에서 고릅니다([구독 형식](../../README.md#구독-형식)).
- AVD service principal은 구독 전체 VM의 전원을 켜고 끌 수 있습니다. 개인 scaling plan의 요구 사항입니다. scaling plan은 이 host pool의 session host에만 동작합니다.
- 탈취된 Agent Forge는 데스크톱을 지우거나 배정을 바꿀 수 있습니다. Azure Activity Log와 Agent Forge 감사 기록으로 탐지합니다.
