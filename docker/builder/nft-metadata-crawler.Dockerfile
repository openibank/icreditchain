### NFT Metadata Crawler Image ###

FROM indexer-builder

FROM debian-base AS nft-metadata-crawler

COPY --link --from=indexer-builder /creditchain/dist/creditchain-nft-metadata-crawler /usr/local/bin/creditchain-nft-metadata-crawler

# The health check port
EXPOSE 8080
