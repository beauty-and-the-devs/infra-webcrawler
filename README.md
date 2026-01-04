# WebCrawler MCP - Terraform Infrastructure

GCP에 WebCrawler MCP 서버를 배포하기 위한 Terraform 구성입니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                           GCP Project                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                      VPC Network                           │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │                    Subnet                            │  │  │
│  │  │  ┌───────────────────────────────────────────────┐  │  │  │
│  │  │  │              GCE VM (Ubuntu 22.04)             │  │  │  │
│  │  │  │  ┌─────────────────────────────────────────┐  │  │  │  │
│  │  │  │  │         Docker Container                 │  │  │  │  │
│  │  │  │  │         (webcrawler-mcp)                 │  │  │  │  │
│  │  │  │  │         - Playwright + Chromium          │  │  │  │  │
│  │  │  │  │         - MCP Server                     │  │  │  │  │
│  │  │  │  └─────────────────────────────────────────┘  │  │  │  │
│  │  │  └───────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────────────────────────┐ │
│  │ Artifact        │    │ Workload Identity Federation        │ │
│  │ Registry        │◄───│ (GitHub Actions OIDC)               │ │
│  │ (Docker Images) │    └─────────────────────────────────────┘ │
│  └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

## 사전 요구사항

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- GCP 프로젝트 (결제 활성화)

### 필요한 GCP API

```bash
gcloud services enable \
  compute.googleapis.com \
  artifactregistry.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com
```

## 빠른 시작

### 1. GCP 인증

```bash
gcloud auth application-default login
```

### 2. 변수 파일 생성

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 편집:

```hcl
# 필수
project_id = "your-gcp-project-id"

# 선택 (GitHub Actions CI/CD 사용 시)
github_repo = "owner/repo-name"

# 선택 (프록시 사용 시)
proxy_server   = "http://proxy.example.com:22225"
proxy_username = "username"
proxy_password = "password"
```

### 3. Terraform 실행

```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply
```

## 변수 (Variables)

### 프로젝트 설정

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `project_id` | GCP 프로젝트 ID | (필수) |
| `project_name` | 리소스 이름 접두사 | `webcrawler-mcp` |
| `environment` | 환경 (dev/staging/prod) | `prod` |

### 리전 설정

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `region` | GCP 리전 | `us-central1` |
| `zone` | GCP 존 | `us-central1-a` |

### 네트워크 설정

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `network_cidr` | VPC 서브넷 CIDR | `10.0.0.0/24` |
| `allowed_ssh_cidrs` | SSH 허용 IP 목록 | `[]` |
| `enable_http_api` | HTTP API 포트 노출 (3000) | `false` |
| `allowed_http_cidrs` | HTTP 허용 IP 목록 | `["0.0.0.0/0"]` |

### 컴퓨트 설정

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `machine_type` | VM 머신 타입 | `e2-standard-2` |
| `boot_disk_size` | 부트 디스크 크기 (GB) | `30` |
| `boot_disk_type` | 디스크 타입 | `pd-balanced` |
| `preemptible` | Spot VM 사용 | `false` |

### 애플리케이션 설정

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `docker_image_tag` | 배포할 이미지 태그 | `latest` |
| `log_level` | 로그 레벨 | `info` |
| `browser_pool_size` | 브라우저 풀 크기 | `2` |
| `rate_limit_rpm` | 분당 요청 제한 | `30` |

### 프록시 설정 (TikTok 안티봇 우회용)

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `proxy_server` | 프록시 서버 URL | `""` |
| `proxy_username` | 프록시 사용자명 | `""` |
| `proxy_password` | 프록시 비밀번호 | `""` |

## 출력값 (Outputs)

배포 완료 후 주요 출력값:

```bash
# 출력값 확인
terraform output

# SSH 접속 명령어
terraform output ssh_iap_command

# Artifact Registry URL
terraform output artifact_registry_repository

# GitHub Secrets 값들
terraform output github_secrets
```

## GitHub Actions CI/CD 설정

### 1. Terraform에서 github_repo 설정

```hcl
github_repo = "your-org/mcp-webcrawler"
```

### 2. GitHub Secrets 설정

`terraform output github_secrets` 결과를 GitHub 저장소 Secrets에 추가:

- `GCP_PROJECT_ID`
- `GCP_REGION`
- `GCP_ZONE`
- `GCP_SERVICE_ACCOUNT`
- `GCP_WORKLOAD_IDENTITY`
- `GCP_ARTIFACT_REGISTRY`
- `GCP_VM_NAME`

### 3. 워크플로우

`main` 브랜치에 푸시하면 자동으로:
1. 빌드 및 테스트
2. Docker 이미지 빌드 & Artifact Registry 푸시
3. VM에 배포

## 유용한 명령어

### VM 접속

```bash
# IAP 터널을 통한 SSH (권장)
gcloud compute ssh webcrawler-mcp-prod-vm \
  --zone=us-central1-a \
  --tunnel-through-iap

# 직접 SSH (allowed_ssh_cidrs 설정 필요)
gcloud compute ssh webcrawler-mcp-prod-vm \
  --zone=us-central1-a
```

### 로그 확인

```bash
# 시작 스크립트 로그
gcloud compute ssh webcrawler-mcp-prod-vm --zone=us-central1-a --tunnel-through-iap \
  --command="sudo cat /var/log/startup-script.log"

# Docker 컨테이너 로그
gcloud compute ssh webcrawler-mcp-prod-vm --zone=us-central1-a --tunnel-through-iap \
  --command="sudo docker logs -f webcrawler-mcp"
```

### 수동 배포

```bash
# VM에서 최신 이미지 풀 & 재배포
gcloud compute ssh webcrawler-mcp-prod-vm --zone=us-central1-a --tunnel-through-iap \
  --command="sudo docker pull <ARTIFACT_REGISTRY>/webcrawler-mcp:latest && \
             sudo docker stop webcrawler-mcp && \
             sudo docker rm webcrawler-mcp && \
             sudo docker run -d --name webcrawler-mcp --restart unless-stopped \
               --shm-size=2gb --env-file /opt/webcrawler-mcp/.env \
               <ARTIFACT_REGISTRY>/webcrawler-mcp:latest"
```

## 비용 최적화

### Spot VM 사용

```hcl
preemptible = true  # ~60-90% 비용 절감, 24시간마다 종료될 수 있음
```

### 작은 머신 타입

```hcl
machine_type = "e2-small"  # 개발/테스트 환경용
```

## 문제 해결

### VM이 시작되지 않음

```bash
# 시리얼 포트 로그 확인
gcloud compute instances get-serial-port-output webcrawler-mcp-prod-vm \
  --zone=us-central1-a
```

### Docker 이미지 풀 실패

```bash
# VM에서 수동으로 인증 확인
gcloud auth configure-docker us-central1-docker.pkg.dev
docker pull <image>
```

### GitHub Actions 인증 실패

1. `github_repo` 변수가 정확한지 확인
2. GitHub Secrets가 모두 설정되었는지 확인
3. Workload Identity Pool이 생성되었는지 확인:
   ```bash
   gcloud iam workload-identity-pools list --location=global
   ```

## 정리 (Destroy)

```bash
terraform destroy
```

> ⚠️ 모든 리소스가 삭제됩니다. Artifact Registry의 Docker 이미지도 함께 삭제됩니다.
