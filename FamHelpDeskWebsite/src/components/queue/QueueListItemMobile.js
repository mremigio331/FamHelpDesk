import React from "react";
import { List, Space, Button, Row, Col } from "antd";
import { InboxOutlined, FileTextOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useQueueListItem } from "./useQueueListItem";

const { Text } = Typography;

const QueueListItemMobile = (props) => {
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
      style={
        onClick
          ? { cursor: "pointer", padding: "12px 0" }
          : { padding: "12px 0" }
      }
      onClick={onClick}
      actions={
        actions
          ? actions
          : defaultActions.map((action) => (
              <Button
                key={action.key}
                type="link"
                size="small"
                style={{ fontSize: "12px", padding: "0 4px" }}
                onClick={action.onClick}
              >
                {action.label}
              </Button>
            ))
      }
    >
      <List.Item.Meta
        avatar={<InboxOutlined style={{ fontSize: "18px" }} />}
        title={
          <Space size={4}>
            <Text style={{ fontSize: "14px", fontWeight: 500 }}>
              {queue.queue_name}
            </Text>
          </Space>
        }
        description={
          <div>
            {queue.queue_description && (
              <div style={{ marginBottom: "6px", fontSize: "12px" }}>
                {queue.queue_description}
              </div>
            )}
            {showCreatedDate && queue.creation_date && (
              <Text type="secondary" style={{ fontSize: "11px" }}>
                Created:{" "}
                {new Date(queue.creation_date * 1000).toLocaleDateString()}
              </Text>
            )}
            {showStats && (
              <Row gutter={8} style={{ marginTop: "8px" }}>
                <Col span={12}>
                  <div style={{ fontSize: "11px" }}>
                    <FileTextOutlined style={{ marginRight: "4px" }} />
                    <Text type="secondary" style={{ fontSize: "11px" }}>
                      Open: {queue.open_ticket_count || 0}
                    </Text>
                  </div>
                </Col>
                <Col span={12}>
                  <div style={{ fontSize: "11px" }}>
                    <FileTextOutlined style={{ marginRight: "4px" }} />
                    <Text type="secondary" style={{ fontSize: "11px" }}>
                      Total: {queue.total_ticket_count || 0}
                    </Text>
                  </div>
                </Col>
              </Row>
            )}
          </div>
        }
      />
    </List.Item>
  );
};

export default QueueListItemMobile;
