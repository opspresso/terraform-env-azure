# AgentOps 회사 계정 로그인

이 root는 Clush 테넌트에 단일 테넌트 웹 애플리케이션과 서비스 주체를 만든다.
AgentOps는 브라우저에서 받은 인가 코드를 서버에서 교환한다. 로그인 앱에는 Azure 구독 역할과 Graph 애플리케이션 권한을 부여하지 않는다. Terraform 실행 주체에는 테넌트의 앱 등록·관리 권한과 backend의 Blob state 접근 권한이 필요하다.

1. `TF_VAR_console_origin`에 시험할 AgentOps HTTPS origin을 지정한다. 값을 배포의 `AUTH_BASE_URL`과 일치시킨다. `TF_VAR_owner_object_ids`에는 앱을 관리할 사용자 또는 서비스 주체의 디렉터리 개체 ID를 JSON 배열로 지정한다. 실행 계정이 바뀌어도 지정한 소유자가 유지된다.
2. 이 디렉터리에서 `terraform init`과 `terraform validate`를 실행한다. 기존 앱을 인수할 때는 이 설치 전용 앱임을 확인한 후 아래 명령을 사용한다. 두 개체 ID는 Entra의 앱 등록과 엔터프라이즈 애플리케이션에서 각각 확인한다.

   ```sh
   terraform import azuread_application.console "/applications/${APPLICATION_OBJECT_ID}"
   terraform import azuread_service_principal.console "${SERVICE_PRINCIPAL_OBJECT_ID}"
   ```

3. `terraform plan`에서 대상 테넌트와 소유자, 웹 리디렉션 두 개, 기존 설정의 변경 범위를 확인한다. 등록을 새로 만드는 경우에는 앱과 서비스 주체가 각각 하나씩 생성된다.
4. 적용 후 `terraform output -raw entra_tenant_id`와 `terraform output -raw entra_client_id`로 식별자를 확인한다.
5. 앱 등록의 **Certificates & secrets**에서 생성한 client secret의 **Value**를 배포의 시크릿 저장소에 직접 등록한다. AgentOps 변수는 `ENTRA_CLIENT_SECRET`이다. 시크릿 값은 Terraform 입력과 state에 저장하지 않는다.
6. AgentOps에 연결한 테스트 사용자가 로그인해 기존 플랫폼 사용자 ID를 받는지 확인한다. 연결하지 않은 회사 계정은 거절되어야 한다.

Forge 데스크톱 배정을 위해 ID token에 선택적 클레임 `upn`을 요청합니다. 적용 후 다시 로그인한 세션부터 이 값을 사용할 수 있습니다.

단일 테넌트에는 초대된 게스트도 있을 수 있다. AgentOps 운영자는 회사 정책에 따라 연결할 디렉터리 개체를 선택한다.
웹 리디렉션은 해당 origin의 `/api/auth/callback`과 `/signed-out`이다.
앱을 등록한 뒤에도 사용자가 접근하려면 AgentOps의 계정 연결 또는 신규 계정 등록이 필요하다. 시크릿을 교체할 때는 새 값을 배포하고 로그인 성공을 확인한 뒤 이전 값을 폐기한다.
