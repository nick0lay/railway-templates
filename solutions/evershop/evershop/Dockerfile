FROM node:20.20.2-alpine

WORKDIR /app

COPY package.json .
RUN npm install

COPY config ./config
COPY entrypoint.sh create-admin.mjs ./
RUN chmod +x entrypoint.sh

RUN mkdir -p extensions themes media public
RUN npx evershop build

ENTRYPOINT ["./entrypoint.sh"]
