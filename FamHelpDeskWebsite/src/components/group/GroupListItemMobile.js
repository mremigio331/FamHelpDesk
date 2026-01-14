import React from "react";
import { List, Tag, Space, Button, Row, Col } from "antd";
import { TeamOutlined, UserOutlined, InboxOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useGroupListItem } from "./useGroupListItem";

const { Text } = Typography;

const GroupListItemMobile = (props) => {
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
        avatar={<TeamOutlined style={{ fontSize: "18px" }} />}
        title={
          <Space size={4}>
            <span style={{ fontSize: "14px", fontWeight: "600" }}>
              {group.group_name}
            </span>
            {showMembershipStatus && statusTag && (
              <Tag color={statusTag.statusColor} style={{ fontSize: "10px" }}>
                {statusTag.statusText}
              </Tag>
            )}
          </Space>
        }
        description={
          <div>
            {group.group_description && (
              <div
                style={{
                  marginBottom: "6px",
                  fontSize: "12px",
                  lineHeight: "1.4",
                }}
              >
                {group.group_description}
              </div>
            )}
            {showCreatedDate && group.creation_date && (
              <Text
                type="secondary"
                style={{ fontSize: "10px", display: "block" }}
              >
                Created:{" "}
                {new Date(group.creation_date * 1000).toLocaleDateString()}
              </Text>
            )}
            {showStats && (
              <Row gutter={8} style={{ marginTop: "8px" }}>
                <Col span={12}>
                  <Space size={4}>
                    <UserOutlined style={{ fontSize: "12px" }} />
                    <Text style={{ fontSize: "11px" }}>
                      {group.member_count || 0} members
                    </Text>
                  </Space>
                </Col>
                <Col span={12}>
                  <Space size={4}>
                    <InboxOutlined style={{ fontSize: "12px" }} />
                    <Text style={{ fontSize: "11px" }}>
                      {group.queue_count || 0} queues
                    </Text>
                  </Space>
                </Col>
              </Row>
            )}
          </div>
        }
      />
    </List.Item>
  );
};

export default GroupListItemMobile;
