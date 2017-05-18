FROM node:latest
MAINTAINER sunkuo <sunkuo@chuxin.ren>

ENV NGINX_VERSION 1.13.0-1~jessie

RUN curl -O -s http://obf68by4u.bkt.clouddn.com/nginx_signing.key && apt-key add nginx_signing.key && \ 
		echo 'deb http://nginx.org/packages/mainline/debian/ jessie nginx' >> /etc/apt/sources.list &&\ 
		echo 'deb-src http://nginx.org/packages/mainline/debian/ jessie nginx' >> /etc/apt/sources.list && rm nginx_signing.key
RUN apt-get update && apt-get install nginx=${NGINX_VERSION}

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

RUN yarn global add node-gyp

# Make use of Docker Cache to install node modules
ONBUILD COPY ./backend/package.json /usr/share/nginx/node/
ONBUILD COPY ./backend/yarn.lock /usr/share/nginx/node/
ONBUILD RUN cd /usr/share/nginx/node && yarn install

ONBUILD COPY ./frontend/package.json /tmp/
ONBUILD COPY ./frontend/yarn.lock /tmp/
ONBUILD RUN cd /tmp && yarn install

ONBUILD COPY ./management-frontend/package.json /management-tmp/
ONBUILD RUN cd /management-tmp && yarn install


# Build Frontend File
ONBUILD COPY ./frontend /tmp/
ONBUILD RUN cd /tmp && yarn run build
ONBUILD RUN mv /tmp/dist /usr/share/nginx/frontend

# Build Management Frontend File
ONBUILD COPY ./management-frontend /management-tmp/
ONBUILD RUN cd /management-tmp && yarn run build
ONBUILD RUN mv /management-tmp/dist /usr/share/nginx/management

# Copy Backend File
ONBUILD COPY ./backend /usr/share/nginx/node/

# Config Nginx
COPY nginx.conf /etc/nginx/conf.d
ONBUILD RUN sed -i s/API_BASE_URL/$API_BASE_URL/g /etc/nginx/conf.d/api.conf \
  && sed -i s/FRONTEND_BASE_URL/$FRONTEND_BASE_URL/g /etc/nginx/conf.d/frontend.conf \
  && sed -i s/MANAGEMENT_FRONTEND_BASE_URL/$MANAGEMENT_FRONTEND_BASE_URL/g /etc/nginx/conf.d/management.frontend.conf

WORKDIR /usr/share/nginx/node/
EXPOSE 80

CMD nginx && node index.js
