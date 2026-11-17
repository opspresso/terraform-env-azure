# 3-domain

Azure DNS zone `dmz.rovr.dev`(리소스 그룹 `rg-dns-dmz`)입니다. Agent Runway 환경 `dmz`의 `vmss` target(`8-runway-target`) 앱 도메인이며,
앱 host는 `<slug>.dmz.rovr.dev`, `<slug>-<env>.dmz.rovr.dev`입니다. 배포 workflow가 앱마다 Front Door CNAME과 `_dnsauth` TXT 레코드를 이 zone에 만듭니다.

부모 zone `rovr.dev`는 AWS 계정 opspresso의 Route53에 있습니다. terraform-env-opsp `demo/8-app-delivery`의 `target_domains`가 이 zone의 name server로
NS 레코드를 만들어 위임합니다. zone을 다시 만들면 name server가 바뀔 수 있으므로 `prevent_destroy`로 보호합니다. 비용은 월 0.50 USD와 query 요금입니다.

## 적용 순서

1. 이 디렉터리를 적용하고 name server를 읽는다.

   ```bash
   terraform output -json name_servers
   ```

2. terraform-env-opsp `demo/8-app-delivery`의 `target_domains`에 `"dmz.rovr.dev" = <name_servers>`를 넣고 적용한다(opspresso 자격 증명).
3. 위임을 확인한다. 응답이 Azure DNS name server 4개면 된다.

   ```bash
   dig +short NS dmz.rovr.dev
   ```
