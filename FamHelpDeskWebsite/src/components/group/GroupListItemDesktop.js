import React from "react";
import { List, Tag, Space, Button, Statistic, Row, Col } from "antd";
import { TeamOutlined, UserOutlined, InboxOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useGroupListItem } from "./useGroupListItem";

const { Text } = Typography;

const GroupListItemDesktop = (props) => {
  const {
    group,
    membership = null,
    actions = null,
    onClick = null,
    showCreatedDate = true,
    showStats = true,
    showMembershipStatus = true,
  } = props;
  const { statusTag, defaultActions } = useGroupListItem({
    group,
    membership,
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
        avatar={<TeamOutlined style={{ fontSize: "24px" }} />}
        title={
          <Space>
            <span>{group.group_name}</span>
            {showMembershipStatus && statusTag && (
              <Tag color={statusTag.statusColor}>{statusTag.statusText}</Tag>
            )}
          </Space>
        }
        description={
          <div>
            {group.group_description && (
              <div style={{ marginBottom: "8px" }}>
                {group.group_description}
              </div>
            )}
            {showCreatedDate && group.creation_date && (
              <Text type="secondary" style={{ fontSize: "12px" }}>
                Created:{" "}
                {new Date(group.creation_date * 1000).toLocaleDateString()}
              </Text>
            )}
            {showStats && (
              <Row gutter={16} style={{ marginTop: "12px" }}>
                <Col>
                  <Statistic
                    title="Members"
                    value={group.member_count || 0}
                    prefix={<UserOutlined />}
                    valueStyle={{ fontSize: "16px" }}
                  />
                </Col>
                <Col>
                  <Statistic
                    title="Queues"
                    value={group.queue_count || 0}
                    prefix={<InboxOutlined />}
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

export default GroupListItemDesktop;
