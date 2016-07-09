FROM mhart/alpine-node:4

# Create app directory
RUN mkdir -p /usr/commercetools/stock-import
WORKDIR /usr/commercetools/stock-import

# Install app dependencies
ADD package.json /usr/commercetools/stock-import/
ADD bin /usr/commercetools/stock-import/bin
ADD lib /usr/commercetools/stock-import/lib
ADD node_modules /usr/commercetools/stock-import/node_modules

CMD [ "/usr/commercetools/stock-import/bin/stock-import" ]
