ARG DEBIAN_VERSION=bookworm-slim
ARG PYTHON_IMAGE_VERSION=3.11
ARG CUDA_VERSION=12.2.0
ARG USE_PREBUILT=true

# ################################################################################
# # Use python image as downloader image for builder and final_stage
# # https://hub.docker.com/_/python
# ################################################################################
FROM python:${PYTHON_IMAGE_VERSION}-slim AS downloader

ENV PYTHONPATH="/dynamic-llamafile-docker"

#-----PARAMS OF THE DYNAMIC LLAMA SERVICE-----
ARG LLAMAFILE_VERSION='0.8.13'
ENV LLAMAFILE_VERSION=${LLAMAFILE_VERSION}

ARG MODEL_NAME='phi3'
ENV MODEL_NAME=${MODEL_NAME}

ARG MODEL_VERSION='1.0'
ENV MODEL_VERSION=${MODEL_VERSION}

ARG MODEL_QTD_PARAMS='13b'
ENV MODEL_QTD_PARAMS=${MODEL_QTD_PARAMS}

ARG MODEL_QUANT_METHOD='q4_k_m'
ENV MODEL_QUANT_METHOD=${MODEL_QUANT_METHOD}

#-----------------------------------------------

COPY src /dynamic-llamafile-docker/src
COPY scripts /dynamic-llamafile-docker/scripts
COPY pyproject.toml poetry.lock ./

RUN pip install -q poetry==1.8.3 && \
    poetry install --only main

RUN poetry run python /dynamic-llamafile-docker/scripts/get_llamafile.py && \
    poetry run python /dynamic-llamafile-docker/scripts/get_llamafile_folder_info.py && \
    poetry run python /dynamic-llamafile-docker/scripts/get_llm_model.py

################################################################################
# Builder
################################################################################

FROM debian:bookworm-slim AS builder

WORKDIR /builder

RUN mkdir out && \
    apt-get update && \
    apt-get install -y curl gcc make unzip zip

COPY --from=downloader /tmp/llamafile.zip ./
COPY --from=downloader /tmp/llamafile_folder_name.txt ./
COPY /third_party/llamafile_after_make.zip ./

# #------------------------------------------------------------------------------------------
# DESCRIÇÃO:

# Recebi este erro no Github Actions:

#*******************************************************************************************************************************************************************************************************************************************************************************************************
# > [builder 6/6] RUN unzip ./llamafile.zip -d ./out/llamafile/ &&     cd ./out/llamafile/$(cat ./llamafile_folder_name.txt) &&     make &&     make install PREFIX=/download/out:
# 22.32   bin/unknown-unknown-cosmo-install -> cosmoinstall
# 22.33   bin/unknown-unknown-cosmo-c++ -> cosmocc
# 22.33   bin/aarch64-unknown-cosmo-c++filt -> aarch64-linux-cosmo-c++filt
# 22.33   bin/x86_64-unknown-cosmo-c++ -> cosmocross
# 22.33   bin/aarch64-unknown-cosmo-ar -> aarch64-linux-cosmo-ar
# 22.33   bin/aarch64-unknown-cosmo-addr2line -> aarch64-linux-cosmo-addr2line
# 22.33   bin/x86_64-unknown-cosmo-strip -> x86_64-linux-cosmo-strip
# 22.47 .cosmocc/3.7.1/bin/cosmocc -O2 -fexceptions -fsignaling-nans -ffunction-sections -fdata-sections -g -DGGML_MULTIPLATFORM -DGGML_USE_LLAMAFILE   -iquote. -mcosmo -DGGML_MULTIPLATFORM -Wno-attributes -DLLAMAFILE_DEBUG  -Xx86_64-mtune=znver4 -c -o o//llamafile/addnl.o llamafile/addnl.c
# 22.47 .cosmocc/3.7.1/bin/cosmocc: 442: .cosmocc/3.7.1/bin/mktemper: not found
# 22.48 make: *** [build/rules.mk:10: o//llamafile/addnl.o] Error 127
# ------
# Dockerfile:75
# --------------------
#     74 |
#     75 | >>> RUN unzip ./llamafile.zip -d ./out/llamafile/ && \
#     76 | >>>     cd ./out/llamafile/$(cat ./llamafile_folder_name.txt) && \
#     77 | >>>     make && \
#     78 | >>>     make install PREFIX=/download/out
#     79 |
# --------------------
# ERROR: failed to solve: process "/bin/sh -c unzip ./llamafile.zip -d ./out/llamafile/ &&     cd ./out/llamafile/$(cat ./llamafile_folder_name.txt) &&     make &&     make install PREFIX=/download/out" did not complete successfully: exit code: 2
# Error: buildx failed with: ERROR: failed to solve: process "/bin/sh -c unzip ./llamafile.zip -d ./out/llamafile/ &&     cd ./out/llamafile/$(cat ./llamafile_folder_name.txt) &&     make &&     make install PREFIX=/download/out" did not complete successfully: exit code: 2
#*******************************************************************************************************************************************************************************************************************************************************************************************************

# Pesquisei e verifiquei que é um erro relacionado com faltas de permissão na
# imagem base que está sendo executado o comando "make", visto que localmente esse
# erro não ocorre, porém no Github Actions sim!

# Inclusive, encontrei esta issue no repositório
# do LLamafile: https://github.com/Mozilla-Ocho/llamafile/issues/225#issuecomment-1908778204

# Desse modo, tentei executar as instruções contidas na issue no dockerfile e
# em uma action do Github Actions, porém sem sucesso!

# Portanto, decidi buildar o Llamafile localmente, comprimir o resultado,
# salvar o arquivo comprimido e descomprimir na nova imagem do "dynamic llamafile service"
#------------------------------------------------------------------------------------------
ENV USE_PREBUILT=${USE_PREBUILT}

RUN if [ "$USE_PREBUILT" = "false" ]; then \
    echo "Building from source [BUILDER]..."; \
    unzip ./llamafile.zip -d ./out/llamafile/ && \
    cd ./out/llamafile/$(cat ./llamafile_folder_name.txt) && \
    make && \
    make install PREFIX=./download/out; \
else \
    echo "Using pre-built files [BUILDER]..."; \
    unzip ./llamafile_after_make.zip -d ./; \
fi

################################################################################
# Use nvidia/cuda image as final image.
# https://dev.to/spara_50/build-a-gpu-enabled-llamafile-container-4n4l
################################################################################

FROM nvidia/cuda:${CUDA_VERSION}-base-ubuntu22.04 AS out

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    linux-headers-$(uname -r) \
    clang \
    cuda-toolkit \
    nvidia-utils-510 && \
    apt-key del 7fa2af80 && \
    rm -rf /var/lib/apt/lists/*

RUN addgroup --gid 1000 user && \
    adduser --uid 1000 --gid 1000 --disabled-password --gecos "" user

WORKDIR /usr/local

COPY --from=downloader /tmp/model.gguf ./
COPY --from=builder /builder/download/out/bin ./bin
COPY --from=builder /builder/download/out/share ./share/man

# Don't write log file.
ENV LLAMA_DISABLE_LOGS=1

RUN chmod +x /usr/local/bin/llamafile

USER user

# Expose 8080 port.
EXPOSE 8080

# Set entrypoint.
ENTRYPOINT ["/bin/sh", "/usr/local/bin/llamafile"]

CMD ["--server", "--nobrowser", "--api-key", "llamafile-t0k3n", "-ngl", "999", "--host", "0.0.0.0", "-m", "/usr/local/model.gguf", "--ctx-size", "512", "--batch-size", "512"]
