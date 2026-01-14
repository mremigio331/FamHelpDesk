import React, { useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Card,
  Typography,
  Button,
  Space,
  Spin,
  Alert,
  Tabs,
  Descriptions,
  Tag,
  Modal,
  message,
  Popconfirm,
  List,
  Avatar,
  Statistic,
  Row,
  Col,
  Drawer,
} from "antd";
import {
  ArrowLeftOutlined,
  EditOutlined,
  DeleteOutlined,
  TeamOutlined,
  UserOutlined,
  InboxOutlined,
  SettingOutlined,
  UserAddOutlined,
  UserDeleteOutlined,
  CrownOutlined,
} from "@ant-design/icons";
import useGroupDetail from "./useGroupDetail";
import useGroups from "../../hooks/group/useGroups";
import useGetGroupMembers from "../../hooks/group/membership/useGetGroupMembers";
import useGetGroupMembershipRequests from "../../hooks/group/membership/useGetGroupMembershipRequests";
import useReviewGroupMembership from "../../hooks/group/membership/useReviewGroupMembership";
import useRemoveGroupMember from "../../hooks/group/membership/useRemoveGroupMember";
import useUpdateGroupMemberRole from "../../hooks/group/membership/useUpdateGroupMemberRole";
import EditGroupModal from "./EditGroupModal";

const { Title, Text, Paragraph } = Typography;

const GroupDetailMobile = () => {
  const { familyId, groupId } = useParams();
  const navigate = useNavigate();

  const {
    activeTab,
    handleTabChange,
    isEditModalVisible,
    showEditModal,
    hideEditModal,
    isDeleteModalVisible,
    showDeleteModal,
    hideDeleteModal,
  } = useGroupDetail();

  const {
    allGroups,
    isLoading: isGroupsLoading,
    hasError: hasGroupsError,
    deleteGroup,
    isDeleting,
    isDeleteSuccess,
    refetchGroups,
  } = useGroups(familyId);

  const {
    members,
    memberCount,
    isFetchingMembers,
    isMembersError,
    refetchMembers,
  } = useGetGroupMembers(familyId, groupId);

  const {
    requests,
    requestCount,
    isFetchingRequests,
    isRequestsError,
    refetchRequests,
  } = useGetGroupMembershipRequests(familyId, groupId);

  const { reviewMembership, isReviewingMembership, isReviewSuccess } =
    useReviewGroupMembership();

  const { removeMember, isRemovingMember, isRemoveMemberSuccess } =
    useRemoveGroupMember();

  const { updateMemberRole, isUpdatingRole, isUpdateRoleSuccess } =
    useUpdateGroupMemberRole();

  // Find the current group
  const group = allGroups?.find((g) => g.group_id === groupId);
  const currentUserMembership = members?.find(
    (m) => m.is_current_user === true,
  );
  const isAdmin = currentUserMembership?.is_admin === true;

  // Handle successful operations

  useEffect(() => {
    if (isDeleteSuccess) {
      message.success("Group deleted successfully");
      navigate(`/family/${familyId}`);
    }
  }, [isDeleteSuccess, navigate, familyId]);

  useEffect(() => {
    if (isReviewSuccess) {
      message.success("Membership request reviewed");
      refetchRequests();
      refetchMembers();
    }
  }, [isReviewSuccess, refetchRequests, refetchMembers]);

  useEffect(() => {
    if (isRemoveMemberSuccess) {
      message.success("Member removed successfully");
      refetchMembers();
    }
  }, [isRemoveMemberSuccess, refetchMembers]);

  useEffect(() => {
    if (isUpdateRoleSuccess) {
      message.success("Member role updated successfully");
      refetchMembers();
    }
  }, [isUpdateRoleSuccess, refetchMembers]);

  const handleDelete = async () => {
    try {
      await deleteGroup({
        family_id: familyId,
        group_id: groupId,
      });
    } catch (error) {
      message.error("Failed to delete group");
      hideDeleteModal();
    }
  };

  const handleApproveRequest = async (userId) => {
    try {
      await reviewMembership({
        familyId: familyId,
        groupId: groupId,
        targetUserId: userId,
        approve: true,
      });
    } catch (error) {
      message.error("Failed to approve membership request");
    }
  };

  const handleRejectRequest = async (userId) => {
    try {
      await reviewMembership({
        familyId: familyId,
        groupId: groupId,
        targetUserId: userId,
        approve: false,
      });
    } catch (error) {
      message.error("Failed to reject membership request");
    }
  };

  const handleRemoveMember = async (userId) => {
    try {
      await removeMember({
        familyId: familyId,
        groupId: groupId,
        targetUserId: userId,
      });
    } catch (error) {
      message.error("Failed to remove member");
    }
  };

  const handleToggleAdmin = async (userId, currentIsAdmin) => {
    try {
      await updateMemberRole({
        familyId: familyId,
        groupId: groupId,
        targetUserId: userId,
        isAdmin: !currentIsAdmin,
      });
    } catch (error) {
      message.error("Failed to update member role");
    }
  };

  if (isGroupsLoading) {
    return (
      <div style={{ padding: "50px", textAlign: "center" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (hasGroupsError || !group) {
    return (
      <div style={{ padding: "16px" }}>
        <Alert
          message="Group Not Found"
          description="This group does not exist or you don't have access to it."
          type="warning"
          showIcon
          action={
            <Button
              type="primary"
              size="small"
              onClick={() => navigate(`/family/${familyId}`)}
            >
              Back to Family
            </Button>
          }
        />
      </div>
    );
  }

  const renderOverview = () => (
    <div>
      <Card size="small" style={{ marginBottom: "12px" }}>
        <Title level={5}>Group Information</Title>
        <Descriptions column={1} size="small">
          <Descriptions.Item label="Name">{group.group_name}</Descriptions.Item>
          <Descriptions.Item label="Description">
            {group.group_description || "No description"}
          </Descriptions.Item>
          <Descriptions.Item label="Created">
            {new Date(group.creation_date * 1000).toLocaleDateString()}
          </Descriptions.Item>
          <Descriptions.Item label="Your Role">
            {isAdmin ? (
              <Tag color="blue" icon={<CrownOutlined />}>
                Admin
              </Tag>
            ) : (
              <Tag color="green">Member</Tag>
            )}
          </Descriptions.Item>
        </Descriptions>
      </Card>

      <Card size="small">
        <Title level={5}>Statistics</Title>
        <Row gutter={[8, 8]}>
          <Col span={24}>
            <Card size="small">
              <Statistic
                title="Members"
                value={memberCount}
                prefix={<UserOutlined />}
              />
            </Card>
          </Col>
          <Col span={24}>
            <Card size="small">
              <Statistic
                title="Queues"
                value={group.queue_count || 0}
                prefix={<InboxOutlined />}
              />
            </Card>
          </Col>
          <Col span={24}>
            <Card size="small">
              <Statistic
                title="Pending Requests"
                value={requestCount}
                prefix={<UserAddOutlined />}
              />
            </Card>
          </Col>
        </Row>
      </Card>
    </div>
  );

  const renderMembers = () => (
    <Card
      size="small"
      title={
        <Space>
          <UserOutlined />
          <span>Members ({memberCount})</span>
        </Space>
      }
    >
      {isFetchingMembers ? (
        <div style={{ textAlign: "center", padding: "20px" }}>
          <Spin />
        </div>
      ) : isMembersError ? (
        <Alert
          message="Error"
          description="Failed to load members"
          type="error"
          showIcon
        />
      ) : (
        <List
          size="small"
          dataSource={members}
          renderItem={(member) => (
            <List.Item
              actions={
                isAdmin && !member.is_current_user
                  ? [
                      <Button
                        key="toggle-admin"
                        type="link"
                        size="small"
                        icon={<CrownOutlined />}
                        onClick={() =>
                          handleToggleAdmin(member.user_id, member.is_admin)
                        }
                        loading={isUpdatingRole}
                      >
                        {member.is_admin ? "Remove Admin" : "Make Admin"}
                      </Button>,
                      <Popconfirm
                        key="remove"
                        title="Remove member?"
                        description="Remove this member from the group?"
                        onConfirm={() => handleRemoveMember(member.user_id)}
                        okText="Yes"
                        cancelText="No"
                      >
                        <Button
                          type="link"
                          size="small"
                          danger
                          icon={<UserDeleteOutlined />}
                          loading={isRemovingMember}
                        >
                          Remove
                        </Button>
                      </Popconfirm>,
                    ]
                  : []
              }
            >
              <List.Item.Meta
                avatar={<Avatar size="small" icon={<UserOutlined />} />}
                title={
                  <Space size="small">
                    <span style={{ fontSize: "14px" }}>
                      {member.user_display_name || member.user_email}
                    </span>
                    {member.is_admin && (
                      <Tag color="blue" icon={<CrownOutlined />}>
                        Admin
                      </Tag>
                    )}
                    {member.is_current_user && <Tag color="green">You</Tag>}
                  </Space>
                }
                description={
                  <Text type="secondary" style={{ fontSize: "12px" }}>
                    {member.user_email}
                  </Text>
                }
              />
            </List.Item>
          )}
        />
      )}
    </Card>
  );

  const renderMembershipRequests = () => {
    if (!isAdmin) {
      return (
        <Card size="small">
          <Alert
            message="Admin Only"
            description="Only group admins can view and manage membership requests."
            type="info"
            showIcon
          />
        </Card>
      );
    }

    return (
      <Card
        size="small"
        title={
          <Space>
            <UserAddOutlined />
            <span>Requests ({requestCount})</span>
          </Space>
        }
      >
        {isFetchingRequests ? (
          <div style={{ textAlign: "center", padding: "20px" }}>
            <Spin />
          </div>
        ) : isRequestsError ? (
          <Alert
            message="Error"
            description="Failed to load membership requests"
            type="error"
            showIcon
          />
        ) : requests.length === 0 ? (
          <Alert
            message="No Pending Requests"
            description="There are no pending membership requests."
            type="info"
            showIcon
          />
        ) : (
          <List
            size="small"
            dataSource={requests}
            renderItem={(request) => (
              <List.Item
                actions={[
                  <Button
                    key="approve"
                    type="primary"
                    size="small"
                    onClick={() => handleApproveRequest(request.user_id)}
                    loading={isReviewingMembership}
                  >
                    Approve
                  </Button>,
                  <Button
                    key="reject"
                    danger
                    size="small"
                    onClick={() => handleRejectRequest(request.user_id)}
                    loading={isReviewingMembership}
                  >
                    Reject
                  </Button>,
                ]}
              >
                <List.Item.Meta
                  avatar={<Avatar size="small" icon={<UserOutlined />} />}
                  title={
                    <span style={{ fontSize: "14px" }}>
                      {request.user_display_name || request.user_email}
                    </span>
                  }
                  description={
                    <Space direction="vertical" size={0}>
                      <Text type="secondary" style={{ fontSize: "12px" }}>
                        {request.user_email}
                      </Text>
                      <Text type="secondary" style={{ fontSize: "11px" }}>
                        {new Date(
                          request.request_date * 1000,
                        ).toLocaleDateString()}
                      </Text>
                    </Space>
                  }
                />
              </List.Item>
            )}
          />
        )}
      </Card>
    );
  };

  const renderQueues = () => (
    <Card size="small">
      <div style={{ textAlign: "center", padding: "40px 20px" }}>
        <InboxOutlined style={{ fontSize: "48px", color: "#bfbfbf" }} />
        <Title level={4} style={{ marginTop: "12px", color: "#595959" }}>
          Queues
        </Title>
        <Text type="secondary" style={{ fontSize: "14px" }}>
          Queue management coming soon
        </Text>
      </div>
    </Card>
  );

  const renderSettings = () => {
    if (!isAdmin) {
      return (
        <Card size="small">
          <Alert
            message="Admin Only"
            description="Only group admins can access group settings."
            type="info"
            showIcon
          />
        </Card>
      );
    }

    return (
      <Card
        size="small"
        title={
          <Space>
            <SettingOutlined />
            <span>Settings</span>
          </Space>
        }
      >
        <Space direction="vertical" size="middle" style={{ width: "100%" }}>
          <div>
            <Title level={5}>Edit Group</Title>
            <Paragraph type="secondary" style={{ fontSize: "13px" }}>
              Update the group name and description.
            </Paragraph>
            <Button
              type="primary"
              block
              icon={<EditOutlined />}
              onClick={showEditModal}
            >
              Edit Group
            </Button>
          </div>

          <div>
            <Title level={5} type="danger">
              Danger Zone
            </Title>
            <Paragraph type="secondary" style={{ fontSize: "13px" }}>
              Deleting a group is permanent and cannot be undone.
            </Paragraph>
            <Button
              danger
              block
              icon={<DeleteOutlined />}
              onClick={showDeleteModal}
            >
              Delete Group
            </Button>
          </div>
        </Space>
      </Card>
    );
  };

  const tabItems = [
    {
      key: "overview",
      label: "Overview",
      children: renderOverview(),
    },
    {
      key: "members",
      label: "Members",
      children: renderMembers(),
    },
    {
      key: "requests",
      label: (
        <span>
          Requests
          {requestCount > 0 && (
            <Tag color="orange" style={{ marginLeft: "4px", fontSize: "10px" }}>
              {requestCount}
            </Tag>
          )}
        </span>
      ),
      children: renderMembershipRequests(),
    },
    {
      key: "queues",
      label: "Queues",
      children: renderQueues(),
    },
    {
      key: "settings",
      label: "Settings",
      children: renderSettings(),
    },
  ];

  return (
    <div style={{ padding: "12px" }}>
      <div style={{ marginBottom: "12px" }}>
        <Button
          type="link"
          icon={<ArrowLeftOutlined />}
          onClick={() => navigate(`/family/${familyId}`)}
          style={{ paddingLeft: 0 }}
        >
          Back
        </Button>
      </div>

      <Card size="small">
        <div style={{ marginBottom: "16px" }}>
          <Space direction="vertical" size="small" style={{ width: "100%" }}>
            <Title level={4} style={{ margin: 0 }}>
              {group.group_name}
            </Title>
            {group.group_description && (
              <Text type="secondary" style={{ fontSize: "13px" }}>
                {group.group_description}
              </Text>
            )}
            {isAdmin && (
              <Space size="small" style={{ width: "100%" }}>
                <Button
                  size="small"
                  icon={<EditOutlined />}
                  onClick={showEditModal}
                  block
                >
                  Edit
                </Button>
                <Button
                  size="small"
                  danger
                  icon={<DeleteOutlined />}
                  onClick={showDeleteModal}
                  block
                >
                  Delete
                </Button>
              </Space>
            )}
          </Space>
        </div>

        <Tabs
          activeKey={activeTab}
          items={tabItems}
          onChange={handleTabChange}
          size="small"
        />
      </Card>

      {/* Edit Group Modal */}
      <EditGroupModal
        visible={isEditModalVisible}
        onClose={hideEditModal}
        group={group}
        onSuccess={() => {
          refetchGroups();
        }}
      />

      {/* Delete Group Modal */}
      <Modal
        title="Delete Group"
        open={isDeleteModalVisible}
        onCancel={hideDeleteModal}
        footer={[
          <Button key="cancel" onClick={hideDeleteModal} block>
            Cancel
          </Button>,
          <Button
            key="delete"
            type="primary"
            danger
            loading={isDeleting}
            onClick={handleDelete}
            block
          >
            Delete Group
          </Button>,
        ]}
      >
        <Alert
          message="Warning"
          description="This action cannot be undone. All queues and data will be permanently deleted."
          type="warning"
          showIcon
          style={{ marginBottom: "12px" }}
        />
        <Paragraph style={{ fontSize: "14px" }}>
          Are you sure you want to delete <strong>{group.group_name}</strong>?
        </Paragraph>
      </Modal>
    </div>
  );
};

export default GroupDetailMobile;
