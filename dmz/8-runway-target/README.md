# 8-runway-target

Agent Runway 계정 `clush-azure`(이 구독)와 환경 `dmz`(`vmss` target)가 쓰는 리소스입니다. Agent Runway는 AWS 계정 opspresso(`396608815058`)의 `eks-demo`에서 실행됩니다.
계약은 agent-platform `docs/APP_DELIVERY.md`의 "계정"이고, 배포 workflow는 argocd-env-projects `charts/delivery/files/app-deploy-vmss.yaml`·`app-remove-vmss.yaml`입니다.

| 리소스 | 이름 | 용도 |
| --- | --- | --- |
| 리소스 그룹 | `rg-agent-runway-dmz` | 아래 공유 리소스 |
| 리소스 그룹 | `rg-agent-runway-dmz-apps` | 배포 workflow가 만드는 앱 리소스(`resourceGroup`). 앱마다 `runway-<project>-<env>` 이름의 identity·load balancer·public IP·VM scale set |
| VNet·subnet | `vnet-agent-runway-dmz`(`10.40.0.0/16`), `snet-apps`(`10.40.0.0/24`) | 앱 instance(`subnetId`). 기본 outbound 접근이 없으므로 instance는 앱 load balancer의 outbound rule로 인터넷에 나간다 |
| NSG | `nsg-agent-runway-dmz-apps` | 인터넷에서는 Front Door(`AzureFrontDoor.Backend`)의 80번 포트만 받는다 |
| Key Vault | `kv-runway-dmz-<구독 앞 8자>` | 환경 `dmz`의 Variable(`keyVault`). RBAC 권한 모델, soft delete 7일, purge protection 없음 |
| Storage account | `strunwaydmz<구독 앞 8자>` | 앱 bundle(`artifactStorage`). shared key 없음, 90일 지난 blob 삭제 |
| Front Door Standard | profile `afd-agent-runway-dmz`, endpoint `runway` | 앱 HTTPS 진입점(`frontDoorProfileId`). 배포 workflow가 앱 host마다 관리형 인증서 custom domain과 route를 더한다 |

DNS zone `dmz.rovr.dev`(`dnsZoneId`)는 `3-domain`이 만들고, 이 root는 그 state를 읽습니다.

## 신원

Entra 앱 두 개는 secret과 인증서가 없습니다. Entra는 `eks-demo` OIDC issuer가 서명한 service account token(audience `api://AzureADTokenExchange`)을
federated credential로 믿습니다. 저장하거나 회전할 비밀이 없습니다.

| Entra 앱 | federated subject | 받는 권한 | 하는 일 |
| --- | --- | --- | --- |
| `agent-runway-target-secrets`(`access.clientId`) | `system:serviceaccount:agent-runway:agent-runway` | Key Vault의 `Key Vault Secrets Officer`, 구독의 `Reader` | Variable을 쓰고 읽고 지운다. 접근 확인 경로 `/agent-runway/_runway/access-check`를 쓴다. 콘솔 선택지(리소스 그룹·VNet·subnet·DNS zone·Front Door profile)를 조회한다 |
| `agent-runway-target-deploy`(`deployClientId`) | `system:serviceaccount:app-delivery:delivery-target` | 앱 리소스 그룹의 `Contributor`, subnet의 `Network Contributor`, DNS zone의 `DNS Zone Contributor`, Front Door profile의 `CDN Profile Contributor`, Storage의 bundle 쓰기 사용자 지정 역할, Key Vault의 `Key Vault Reader`, Key Vault·Storage의 조건부 `Role Based Access Control Administrator` | 앱 리소스를 만들고 지운다. bundle을 올린다. 앱 identity에 역할을 준다 |

deploy 앱의 역할 할당 권한은 조건으로 제한합니다. service principal에게 `Key Vault Secrets User`나 `Storage Blob Data Reader`만 주거나 거둘 수 있습니다.
배포 workflow는 앱 identity에 그 앱이 선언한 secret마다 `Key Vault Secrets User`를, 그 앱의 bundle container에 `Storage Blob Data Reader`를 줍니다.
instance는 부팅할 때 앱 identity로 secret과 bundle을 읽습니다. Variable 값은 workflow와 template을 거치지 않습니다. deploy 앱은 Variable의 이름과 태그만 읽습니다.

Agent Runway와 배포 step의 pod에는 audience `api://AzureADTokenExchange`인 projected service account token이 있어야 합니다(argocd-env-apps의 Agent Runway chart, argocd-env-projects `charts/delivery`).

## 준비

- 구독이 종량제(Pay-As-You-Go) 이상이어야 합니다. Free Trial은 Front Door를 거절합니다([구독 형식](../../README.md#구독-형식)).
- `3-domain`을 먼저 적용합니다. terraform-env-opsp `demo/8-app-delivery`가 `dmz.rovr.dev`를 위임해야 Front Door 관리형 인증서가 발급됩니다.
- 적용하는 사용자는 구독 Owner와 테넌트 앱 등록 권한이 필요합니다. Entra 앱의 owner는 적용한 사용자입니다.

## 적용 순서

1. 이 디렉터리를 적용합니다.

   ```bash
   terraform init
   terraform plan
   terraform apply
   terraform output -json account
   terraform output -json vmss_target
   ```

2. Agent Runway 관리자가 콘솔 **관리 > 계정 > 계정 추가**에서 클라우드 Azure를 고르고 출력 `account`의 값을 넣어 저장한 뒤 **접근 확인**을 누릅니다.
   성공하면 `verifiedAt`이 기록됩니다. 실패하면 화면의 오류를 확인합니다. role assignment가 퍼지는 데 몇 분 걸릴 수 있습니다.
3. 관리자가 **관리 > 환경 > 환경 추가**에서 계정 `clush-azure`, 종류 VM scale set을 고르고 리소스 그룹·VNet·subnet·DNS zone·Front Door profile·플랫폼을 고릅니다.
   선택지는 구독에서 조회됩니다. 값은 출력 `vmss_target`과 같습니다. 환경 이름은 `dmz`입니다.

## 비용과 위험

- 고정 비용은 Front Door Standard 월 약 35 USD, Key Vault 작업 요금, Storage 저장 요금입니다. 앱마다 Standard load balancer·public IP(월 약 22 USD)와 VM 비용이 따로 듭니다.
- deploy 앱은 앱 리소스 그룹 전체의 `Contributor`입니다. 이 리소스 그룹에는 Agent Runway가 만든 앱 리소스만 둡니다.
- Key Vault를 지우면 저장한 Variable을 잃습니다. soft delete 기간(7일) 안에는 `az keyvault recover`로 되살릴 수 있습니다.
