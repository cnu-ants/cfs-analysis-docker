# cFS 빌드 환경

macOS 또는 Linux의 Bash 기준. Docker가 설치되어 있고 실행 중이어야 한다.
cFS `v7.0.2-rc1-oss`를 Ubuntu 24.04에서 GCC 13.3으로 빌드한다. 아래 예시의 대상은 `linux/amd64`, 빌드 설정은 `native_std`다. Apple Silicon 등 ARM64 호스트에서 이 예시를 실행하려면 Docker의 AMD64 에뮬레이션 지원이 필요하다.

## 빌드

`docker/`와 `scripts/`가 있는 프로젝트 최상위 폴더에서 실행한다. Dockerfile이 `scripts/`의 파일을 복사하므로 공유할 때도 두 폴더를 같이 둔다.

```bash
docker build --platform linux/amd64 -f docker/cfs/Dockerfile -t cfs:amd64 .
```

빌드 중에 cFS 소스와 서브모듈을 내려받고 컴파일까지 한다. 이미지 안에서 소스는 `/cFS`, 빌드 결과는 `/cFS/build-native_std`에 있다.

## 컨테이너 실행

로컬 `analyzer` 폴더에는 자체 분석기를 넣고, `results` 폴더에는 결과를 저장한다.

```bash
mkdir -p analyzer results
docker run --platform linux/amd64 -d --rm --name cfs-dev \
  --sysctl fs.mqueue.msg_max=512 --sysctl fs.mqueue.queues_max=512 \
  --mount "type=bind,source=$(pwd)/analyzer,target=/analyzer,readonly" \
  --mount "type=bind,source=$(pwd)/results,target=/reports" \
  -w /cFS cfs:amd64 sleep infinity
```

CPU1의 cFS를 직접 실행하려면 아래 명령을 쓴다. 로그에 `CFE_ES_Main entering OPERATIONAL state`가 나오면 기동한 것이다. `Ctrl+C`로 종료한다.

```bash
docker exec -it -w /cFS/build-native_std/exe/cpu1 cfs-dev ./core-cpu1
```

## 자체 분석기 실행

`analyzer` 폴더에 Linux AMD64용 실행 파일이나 스크립트를 넣고 컨테이너 셸을 연다.

```bash
docker exec -it cfs-dev bash
```

셸에서 `/analyzer` 아래의 분석기를 실행한다. 분석기가 컴파일 DB를 입력받으면 대상 CPU에 맞춰 아래 파일을 사용한다.

```text
CPU1  /cFS/build-native_std/native/default_cpu1/compile_commands.json
CPU2  /cFS/build-native_std/native/default_cpu2/compile_commands.json
```

DB에는 소스별 컴파일 옵션과 헤더 경로가 들어 있다. 분석기끼리 결과를 비교할 때는 같은 CPU의 DB와 같은 소스 목록을 쓴다. 결과를 `/reports`에 쓰면 호스트의 `results` 폴더에 남는다. `exit`로 호스트 터미널에 돌아온다.

## 테스트와 종료

cFS를 잠깐 띄워 기동을 확인하는 테스트와 CPU1 단위 테스트다. 앞에서 직접 실행한 cFS를 종료한 뒤 돌린다.

```bash
docker exec cfs-dev cfs-smoke-test.sh
docker exec cfs-dev cfs-unit-tests.sh
```

로그와 단위 테스트 XML은 `results`에서 확인한다. 작업이 끝나면 컨테이너를 내린다.

```bash
docker stop cfs-dev
```
