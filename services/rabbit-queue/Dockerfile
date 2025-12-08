FROM rabbitmq:3.12-alpine

# Enable management plugin
RUN rabbitmq-plugins enable --offline rabbitmq_management

# Expose AMQP and Management ports
EXPOSE 5672 15672

# Use default entrypoint from base image
CMD ["rabbitmq-server"]