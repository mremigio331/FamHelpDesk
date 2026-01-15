import React from "react";
import { List, Space, Button, Statistic, Row, Col } from "antd";
import { InboxOutlined, FileTextOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useQueueListItem } from "./useQueueListItem";

const { Text } = Typography;

const QueueListItemDesktop = (props) => {
  const {
    queue,
    actions = null,
    onClick = null,
    showCreatedDate = true,
    showStats = true,
  } = props;
  const { defaultActions } = useQueueListItem({
    queue,
    actions,
  });

  return (
    <List.Item
      style={onClick ? { cursor: "pointer" } : {}}
      onClick={onClick}
      actions={
        actions
          ? actions
          : defaultActions.map((action) => (
              <Button key={action.key} type="link" onClick={action.onClick}>
                {action.label}
              </Button>
            ))
      }
    >
      <List.Item.Meta
        avatar={<InboxOutlined style={{ fontSize: "24px" }} />}
        title={<Space>{queue.queue_name}</Space>}
        description={
          <div>
            {queue.queue_description && (
              <div style={{ marginBottom: "8px" }}>
                {queue.queue_description}
              </div>
            )}
            {showCreatedDate && queue.creation_date && (
              <Text type="secondary" style={{ fontSize: "12px" }}>
                Created:{" "}
                {new Date(queue.creation_date * 1000).toLocaleDateString()}
              </Text>
            )}
            {showStats && (
              <Row gutter={16} style={{ marginTop: "12px" }}>
                <Col>
                  <Statistic
                    title="Open Tickets"
                    value={queue.open_ticket_count || 0}
                    prefix={<FileTextOutlined />}
                    valueStyle={{ fontSize: "16px" }}
                  />
                </Col>
                <Col>
                  <Statistic
                    title="Total Tickets"
                    value={queue.total_ticket_count || 0}
                    prefix={<FileTextOutlined />}
                    valueStyle={{ fontSize: "16px" }}
                  />
                </Col>
              </Row>
            )}
          </div>
        }
      />
    </List.Item>
  );
};

export default QueueListItemDesktop;
