FROM node:lts-alpine

RUN mkdir -p /home/node/app/node_modules && \
  mkdir -p /home/node/app/app && \
  chown -R node:node /home/node

WORKDIR /home/node/app

COPY --chown=node:node /frontend/package*.json ./

USER node

RUN npm install && \
  npm run build

COPY --chown=node:node /frontend ./app

EXPOSE 3000

CMD [ "npm", "run", "dev" ]
