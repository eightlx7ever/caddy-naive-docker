# syntax=docker/dockerfile:1

# =====================================================
# 1. Build stage
# =====================================================

ARG CADDY_VERSION=2.11.7

# 使用 Caddy 官方 Builder 镜像
FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

ARG CADDY_VERSION
ARG FORWARDPROXY_COMMIT

# 确保必须使用明确的 Commit SHA
RUN test -n "${FORWARDPROXY_COMMIT}" \
    && echo "Caddy version: ${CADDY_VERSION}" \
    && echo "forwardproxy commit: ${FORWARDPROXY_COMMIT}"

# 编译 Caddy，并使用 klzgrad 的 naive 分支实现
RUN xcaddy build "v${CADDY_VERSION}" \
    --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@${FORWARDPROXY_COMMIT}

# 验证 Caddy 版本及插件
RUN /usr/bin/caddy version \
    && /usr/bin/caddy list-modules \
       | grep -Fx "http.handlers.forward_proxy"


# =====================================================
# 2. Runtime stage
# =====================================================

# 固定 Alpine 3.24 系列，允许该系列的安全补丁更新
FROM alpine:3.24

LABEL org.opencontainers.image.title="Caddy NaiveProxy Server"
LABEL org.opencontainers.image.description="Caddy with klzgrad forwardproxy naive fork"
LABEL org.opencontainers.image.source="https://github.com/klzgrad/forwardproxy"

# 安装最少的运行依赖，创建非 root 用户
RUN apk add --no-cache ca-certificates \
    && addgroup -S -g 10001 caddy \
    && adduser -S -D -H -u 10001 -G caddy caddy \
    && mkdir -p /etc/caddy /data /config /srv \
    && chown -R caddy:caddy /etc/caddy /data /config /srv

# 复制构建阶段生成的 Caddy 二进制
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

RUN chmod 0755 /usr/bin/caddy

# 使用非 root 用户运行
USER 10001:10001

EXPOSE 80 443

ENTRYPOINT ["/usr/bin/caddy"]

CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
