import React, { useState } from "react";
import {
  Card,
  List,
  Typography,
  Space,
  Empty,
  Spin,
  Alert,
  Button,
  Modal,
  Tag,
  Popconfirm,
  Avatar,
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

const { Title, Text } = Typography;

const ManageMembersDesktop = ({ familyId, currentUserId }) => {
  const [isModalVisible, setIsModalVisible] = useState(false);
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

  const renderMemberItem = (member) => {
    const isCurrentUser = member.user_id === currentUserId;

    return (
      <List.Item
        key={member.user_id}
        style={{
          padding: "16px",
          backgroundColor: "#fafafa",
          borderRadius: "8px",
          marginBottom: "12px",
        }}
      >
        <List.Item.Meta
          avatar={
            <Avatar
              size={48}
              icon={<UserOutlined />}
              style={{
                backgroundColor: member.is_admin ? "#faad14" : "#52c41a",
              }}
            />
          }
          title={
            <Space>
              <Text strong style={{ fontSize: "16px" }}>
                {member.user_display_name || "Unknown User"}
              </Text>
              {member.is_admin && (
                <Tag color="gold" icon={<CrownOutlined />}>
                  Admin
                </Tag>
              )}
              {isCurrentUser && <Tag color="blue">You</Tag>}
            </Space>
          }
          description={
            <Space direction="vertical" size="small">
              <Text type="secondary">{member.user_email}</Text>
              {member.request_date && (
                <Text type="secondary" style={{ fontSize: "12px" }}>
                  Member since:{" "}
                  {new Date(member.request_date).toLocaleDateString()}
                </Text>
              )}
            </Space>
          }
        />
      </List.Item>
    );
  };

  const renderManagementModal = () => {
    const isProcessing = (userId) => processingUserId === userId;

    return (
      <Modal
        title={
          <Space>
            <SettingOutlined />
            <span>Manage Member Roles</span>
          </Space>
        }
        open={isModalVisible}
        onCancel={() => setIsModalVisible(false)}
        footer={null}
        width={700}
      >
        <Alert
          message="Admin Management"
          description="Promote members to admin, demote admins to regular members, or remove members from the family. You cannot modify your own role or remove yourself."
          type="info"
          showIcon
          style={{ marginBottom: 16 }}
        />

        <List
          itemLayout="horizontal"
          dataSource={members}
          renderItem={(member) => {
            const isCurrentUser = member.user_id === currentUserId;
            const processing = isProcessing(member.user_id);

            return (
              <List.Item
                key={member.user_id}
                actions={[
                  <Space key="actions" size="small">
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
                        <div style={{ maxWidth: 300 }}>
                          <Text>
                            Are you sure you want to remove{" "}
                            <Text strong>{member.user_display_name}</Text> from
                            this family?
                          </Text>
                          <br />
                          <Text type="warning" style={{ fontSize: "12px" }}>
                            This action cannot be undone.
                          </Text>
                        </div>
                      }
                      onConfirm={() => handleRemoveMember(member)}
                      okText="Remove"
                      cancelText="Cancel"
                      okButtonProps={{ danger: true }}
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
                  </Space>,
                ]}
              >
                <List.Item.Meta
                  avatar={
                    <Avatar
                      size={40}
                      icon={<UserOutlined />}
                      style={{
                        backgroundColor: member.is_admin ? "#faad14" : "#52c41a",
                      }}
                    />
                  }
                  title={
                    <Space>
                      <Text strong>{member.user_display_name || "Unknown User"}</Text>
                      {member.is_admin && (
                        <Tag color="gold" icon={<CrownOutlined />}>
                          Admin
                        </Tag>
                      )}
                      {isCurrentUser && <Tag color="blue">You</Tag>}
                    </Space>
                  }
                  description={<Text type="secondary">{member.user_email}</Text>}
                />
              </List.Item>
            );
          }}
        />
      </Modal>
    );
  };

  if (isFetchingMembers) {
    return (
      <Card>
        <div style={{ textAlign: "center", padding: "40px" }}>
          <Spin size="large" />
          <div style={{ marginTop: 16 }}>
            <Text type="secondary">Loading members...</Text>
          </div>
        </div>
      </Card>
    );
  }

  if (isMembersError) {
    return (
      <Card>
        <Alert
          message="Error Loading Members"
          description={membersError?.message || "An error occurred"}
          type="error"
          showIcon
        />
      </Card>
    );
  }

  return (
    <>
      <Card
        title={
          <Space>
            <UserOutlined />
            <span>Family Members</span>
            {memberCount > 0 && (
              <Tag color="blue">
                {memberCount} {memberCount === 1 ? "Member" : "Members"}
              </Tag>
            )}
          </Space>
        }
        extra={
          <Button
            type="primary"
            icon={<SettingOutlined />}
            onClick={() => setIsModalVisible(true)}
          >
            Manage Membership
          </Button>
        }
      >
        {members.length === 0 ? (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description="No members found"
            style={{ padding: "40px 0" }}
          />
        ) : (
          <List
            itemLayout="horizontal"
            dataSource={members}
            renderItem={renderMemberItem}
          />
        )}
      </Card>

      {renderManagementModal()}
    </>
  );
};

export default ManageMembersDesktop;
