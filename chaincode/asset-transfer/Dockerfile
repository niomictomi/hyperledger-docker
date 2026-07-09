FROM golang:1.21-alpine AS builder

WORKDIR /chaincode

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o chaincode .

FROM alpine:3.18

RUN apk add --no-cache ca-certificates
WORKDIR /chaincode

COPY --from=builder /chaincode/chaincode .
COPY --from=builder /chaincode/metadata .

EXPOSE 9999

CMD ["./chaincode"]
