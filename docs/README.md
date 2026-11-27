# AgentOps Azure 인프라 문서

## 문서 안내

| 문서 | 내용 |
| --- | --- |
| [Terraform 운영과 작성 규칙](OPERATIONS.md) | root 적용 순서, 구독 요건, 파일 이름과 provider·backend 배치 규칙을 확인합니다. |
| [Azure DNS](../dmz/3-domain/README.md) | DNS zone과 NS 위임 절차를 확인합니다. |
| [AgentOps Entra 로그인](../dmz/8-agentops-login/README.md) | 로그인 앱 등록과 운영 값을 확인합니다. |
| [Runway Azure 대상](../dmz/8-runway-target/README.md) | 배포 대상 네트워크·Vault·Storage와 권한을 확인합니다. |
| [Forge 개발자 데스크톱](../dmz/8-forge-desktop/README.md) | AVD 기반과 데스크톱 풀 준비 절차를 확인합니다. |
| [Windows 이미지](../images/dev-desktop-win10/README.md) | Packer 빌드와 Compute Gallery 게시 절차를 확인합니다. |

## 프로젝트 구조

| 경로 | 역할 |
| --- | --- |
| [dmz/](../dmz/) | DNS·로그인·Runway·Forge별로 독립된 Terraform root와 backend가 있습니다. |
| [images/dev-desktop-win10/](../images/dev-desktop-win10/) | 개발자 데스크톱용 Packer 템플릿과 이미지 준비 파일입니다. |
| [scripts/check-layout.sh](../scripts/check-layout.sh) | dmz 하위 root의 버전·provider·state·파일 배치를 검사합니다. |
| [.github/workflows/](../.github/workflows/) | 저장소에 정의한 인프라 검증 워크플로입니다. |
