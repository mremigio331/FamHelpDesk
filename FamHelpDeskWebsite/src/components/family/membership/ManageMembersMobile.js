import React, { useState } from "react";
import {
  Space,
  Empty,
  Spin,
  Alert,
  Button,
  Card,
  Typography,
  Tag,
  Avatar,
  Drawer,
  List,
  Popconfirm,
} from "antd";
import {
  UserOutlined,
  CrownOutlined,
  DeleteOutlined,
  WarningOutlined,
  SettingOutlined,
} from "@ant-design/icons";
import useGetFamilyMembers from "../../../hooks/membership/useGetFamilyMembers";
import useUpdateFamilyMemberRole from "../../../hooks/membership/useUpdateFamilyMemberRole";
import useRemoveFamilyMember from "../../../hooks/membership/useRemoveFamilyMember";

const { Text } = Typography;

const ManageMembersMobile = ({ familyId, currentUserId }) => {
  const [isDrawerVisible, setIsDrawerVisible] = useState(false);
  const [processingUserId, setProcessingUserId] = useState(null);

  const { members, memberCount, isFetchingMembers, isMembersError, membersError } =
    useGetFamilyMembers(familyId);

  const { updateMemberRole, isUpdatingRole } = useUpdateFamilyMemberRole(familyId);
  const { removeMember, isRemoving } = useRemoveFamilyMember(familyId);

  const handleMakeAdmin = async (member) => {
    setProcessingUserId(member.user_id);
    try {
      await updateMemberRole({
        targetUserId: member.user_id,
        isAdmin: true,
      });
    } finally {
      setProcessingUserId(null);
    }
  };

  const handleRemoveAdmin = async (member) => {
    setProcessingUserId(member.user_id);
    try {
      await updateMemberRole({
        targetUserId: member.user_id,
        isAdmin: false,
      });
    } finally {
      setProcessingUserId(null);
    }
  };

  const handleRemoveMember = async (member) => {
    setProcessingUserId(member.user_id);
    try {
      await removeMember({ targetUserId: member.user_id });
    } finally {
      setProcessingUserId(null);
    }
  };

  const renderMemberCard = (member) => {
    const isCurrentUser = member.user_id === currentUserId;

    return (
      <Card
        key={member.user_id}
        size="small"
        style={{
          backgroundColor: "#fafafa",
          borderRadius: "8px",
        }}
      >
        <Space direction="vertical" size="small" style={{ width: "100%" }}>
          <Space size="middle" style={{ width: "100%" }}>
            <Avatar
              size={40}
              icon={<UserOutlined />}
              style={{
                backgroundColor: member.is_admin ? "#faad14" : "#52c41a",
              }}
            />
            <Space direction="vertical" size={0} style={{ flex: 1 }}>
              <Space size="small" wrap>
                <Text strong style={{ fontSize: "14px" }}>
                  {member.user_display_name || "Unknown User"}
                </Text>
                {member.is_admin && (
                  <Tag color="gold" icon={<CrownOutlined />} style={{ fontSize: "10px" }}>
                    Admin
                  </Tag>
                )}
                {isCurrentUser && (
                  <Tag color="blue" style={{ fontSize: "10px" }}>
                    You
                  </Tag>
                )}
              </Space>
              <Text type="secondary" style={{ fontSize: "12px" }}>
                {member.user_email}
              </Text>
              {member.request_date && (
                <Text type="secondary" style={{ fontSize: "11px" }}>
                  Since: {new Date(member.request_date).toLocaleDateString()}
                </Text>
              )}
            </Space>
          </Space>
        </Space>
      </Card>
    );
  };

  const renderManagementDrawer = () => {
    const isProcessing = (userId) => processingUserId === userId;

    return (
      <Drawer
        title={
          <Space>
            <SettingOutlined />
            <span>Manage Members</span>
          </Space>
        }
        placement="bottom"
        height="80%"
        open={isDrawerVisible}
        onClose={() => setIsDrawerVisible(false)}
      >
        <Space direction="vertical" size="medium" style={{ width: "100%" }}>
          <Alert
            message="Admin Management"
            description="Manage member roles and remove members. You cannot modify your own role."
            type="info"
            showIcon
            style={{ fontSize: "12px" }}
          />

          <List
            itemLayout="vertical"
            dataSource={members}
            renderItem={(member) => {
              const isCurrentUser = member.user_id === currentUserId;
              const processing = isProcessing(member.user_id);

              return (
                <Card
                  key={member.user_id}
                  size="small"
                  style={{ marginBottom: 12 }}
                >
                  <Space direction="vertical" size="small" style={{ width: "100%" }}>
                    <Space size="middle" style={{ width: "100%" }}>
                      <Avatar
                        size={36}
                        icon={<UserOutlined />}
                        style={{
                          backgroundColor: member.is_admin ? "#faad14" : "#52c41a",
                        }}
                      />
                      <Space direction="vertical" size={0} style={{ flex: 1 }}>
                        <Space size="small" wrap>
                          <Text strong style={{ fontSize: "13px" }}>
                            {member.user_display_name || "Unknown User"}
                          </Text>
                          {member.is_admin && (
                            <Tag color="gold" icon={<CrownOutlined />} style={{ fontSize: "10px" }}>
                              Admin
                            </Tag>
                          )}
                          {isCurrentUser && (
                            <Tag color="blue" style={{ fontSize: "10px" }}>
                              You
                            </Tag>
                          )}
                        </Space>
                        <Text type="secondary" style={{ fontSize: "11px" }}>
                          {member.user_email}
                        </Text>
                      </Space>
                    </Space>

                    <Space
                      style={{
                        width: "100%",
                        justifyContent: "flex-end",
                        paddingTop: 8,
                        borderTop: "1px solid #f0f0f0",
                      }}
                      size="small"
                    >
                      {member.is_admin ? (
                        <Button
                          size="small"
                          onClick={() => handleRemoveAdmin(member)}
                          disabled={isCurrentUser || processing}
                          loading={processing && isUpdatingRole}
                        >
                          Remove Admin
                        </Button>
                      ) : (
                        <Button
                          type="primary"
                          size="small"
                          icon={<CrownOutlined />}
                          onClick={() => handleMakeAdmin(member)}
                          disabled={isCurrentUser || processing}
                          loading={processing && isUpdatingRole}
                        >
                          Make Admin
                        </Button>
                      )}

                      <Popconfirm
                        title="Remove Member"
                        description={
                          <div style={{ maxWidth: 250 }}>
                            <Text style={{ fontSize: "12px" }}>
                              Remove <Text strong>{member.user_display_name}</Text>?
                            </Text>
                            <br />
                            <Text type="warning" style={{ fontSize: "11px" }}>
                              This cannot be undone.
                            </Text>
                          </div>
                        }
                        onConfirm={() => handleRemoveMember(member)}
                        okText="Remove"
                        cancelText="Cancel"
                        okButtonProps={{ danger: true, size: "small" }}
                        cancelButtonProps={{ size: "small" }}
                        disabled={isCurrentUser || processing}
                        icon={<WarningOutlined style={{ color: "red" }} />}
                      >
                        <Button
                          danger
                          size="small"
                          icon={<DeleteOutlined />}
                          disabled={isCurrentUser || processing}
                          loading={processing && isRemoving}
                        >
                          Remove
                        </Button>
                      </Popconfirm>
                    </Space>
                  </Space>
                </Card>
              );
            }}
          />
        </Space>
      </Drawer>
    );
  };

  if (isFetchingMembers) {
    return (
      <div style={{ textAlign: "center", padding: "40px 20px" }}>
        <Spin size="large" />
        <div style={{ marginTop: 16 }}>
          <Text type="secondary" style={{ fontSize: "12px" }}>
            Loading members...
          </Text>
        </div>
      </div>
    );
  }

  if (isMembersError) {
    return (
      <Alert
        message="Error"
        description={membersError?.message || "Failed to load members"}
        type="error"
        showIcon
        style={{ fontSize: "12px" }}
      />
    );
  }

  return (
    <>
      <Space direction="vertical" size="medium" style={{ width: "100%" }}>
        <Button
          type="primary"
          icon={<SettingOutlined />}
          onClick={() => setIsDrawerVisible(true)}
          block
          size="small"
        >
          Manage Membership
        </Button>

        {members.length === 0 ? (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description="No members found"
            style={{ padding: "20px 0", fontSize: "12px" }}
          />
        ) : (
          <Space direction="vertical" size="small" style={{ width: "100%" }}>
            {members.map(renderMemberCard)}
          </Space>
        )}
      </Space>

      {renderManagementDrawer()}
    </>
  );
};

export default ManageMembersMobile;
