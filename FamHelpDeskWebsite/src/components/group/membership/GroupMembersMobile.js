import React, { useState } from "react";
import { Space, Empty, Spin, Alert, Segmented, Button } from "antd";
import {
  UserOutlined,
  ClockCircleOutlined,
  UserAddOutlined,
} from "@ant-design/icons";
import useGetGroupMembers from "../../../hooks/group/membership/useGetGroupMembers";
import useGetGroupMembershipRequests from "../../../hooks/group/membership/useGetGroupMembershipRequests";
import useReviewGroupMembership from "../../../hooks/group/membership/useReviewGroupMembership";
import useRemoveGroupMember from "../../../hooks/group/membership/useRemoveGroupMember";
import useUpdateGroupMemberRole from "../../../hooks/group/membership/useUpdateGroupMemberRole";
import {
  handleApproveGroupMembership,
  handleRejectGroupMembership,
  handleRemoveGroupMember,
  handleToggleGroupMemberRole,
} from "./groupMembershipUtils";
import GroupMemberCardMobile from "./GroupMemberCardMobile";
import GroupMembershipRequestCardMobile from "./GroupMembershipRequestCardMobile";
import AddGroupMemberModal from "./AddGroupMemberModal";

const GroupMembersMobile = ({ familyId, groupId, isAdmin }) => {
  const [activeTab, setActiveTab] = useState("members");
  const [isAddMemberModalVisible, setIsAddMemberModalVisible] = useState(false);

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

  const { reviewMembership, isReviewingMembership } =
    useReviewGroupMembership();

  const { removeMember, isRemovingMember } = useRemoveGroupMember();

  const { updateMemberRole, isUpdatingRole } = useUpdateGroupMemberRole();

  const handleApprove = (targetUserId, displayName) => {
    handleApproveGroupMembership(
      reviewMembership,
      familyId,
      groupId,
      targetUserId,
      displayName,
    );
    // Refetch after a short delay to allow backend to update
    setTimeout(() => {
      refetchRequests();
      refetchMembers();
    }, 500);
  };

  const handleReject = (targetUserId, displayName) => {
    handleRejectGroupMembership(
      reviewMembership,
      familyId,
      groupId,
      targetUserId,
      displayName,
    );
    // Refetch after a short delay to allow backend to update
    setTimeout(() => {
      refetchRequests();
    }, 500);
  };

  const handleRemove = (targetUserId, displayName) => {
    handleRemoveGroupMember(
      removeMember,
      familyId,
      groupId,
      targetUserId,
      displayName,
    );
    // Refetch after a short delay to allow backend to update
    setTimeout(() => {
      refetchMembers();
    }, 500);
  };

  const handleToggleAdmin = (targetUserId, currentIsAdmin, displayName) => {
    handleToggleGroupMemberRole(
      updateMemberRole,
      familyId,
      groupId,
      targetUserId,
      currentIsAdmin,
      displayName,
    );
    // Refetch after a short delay to allow backend to update
    setTimeout(() => {
      refetchMembers();
    }, 500);
  };

  const handleAddMemberSuccess = () => {
    // Refetch members after adding
    setTimeout(() => {
      refetchMembers();
    }, 500);
  };

  const renderContent = () => {
    if (activeTab === "members") {
      if (isFetchingMembers) {
        return (
          <div style={{ textAlign: "center", padding: "40px 20px" }}>
            <Spin size="large" />
          </div>
        );
      }

      if (isMembersError) {
        return (
          <Alert
            message="Error"
            description="Failed to load members"
            type="error"
            showIcon
            style={{ fontSize: "12px" }}
          />
        );
      }

      if (members.length === 0) {
        return (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description="No members found"
            style={{ padding: "20px 0", fontSize: "12px" }}
          />
        );
      }

      return (
        <Space direction="vertical" size="small" style={{ width: "100%" }}>
          {members.map((member) => (
            <GroupMemberCardMobile
              key={member.user_id}
              member={member}
              isAdmin={isAdmin}
              isCurrentUser={member.is_current_user}
              isUpdatingRole={isUpdatingRole}
              isRemovingMember={isRemovingMember}
              onToggleAdmin={handleToggleAdmin}
              onRemoveMember={handleRemove}
            />
          ))}
        </Space>
      );
    }

    // Requests tab
    if (!isAdmin) {
      return (
        <Alert
          message="Admin Only"
          description="Only group admins can view and manage membership requests."
          type="info"
          showIcon
          style={{ fontSize: "12px" }}
        />
      );
    }

    if (isFetchingRequests) {
      return (
        <div style={{ textAlign: "center", padding: "40px 20px" }}>
          <Spin size="large" />
        </div>
      );
    }

    if (isRequestsError) {
      return (
        <Alert
          message="Error"
          description="Failed to load requests"
          type="error"
          showIcon
          style={{ fontSize: "12px" }}
        />
      );
    }

    if (requests.length === 0) {
      return (
        <Empty
          image={Empty.PRESENTED_IMAGE_SIMPLE}
          description="No pending requests"
          style={{ padding: "20px 0", fontSize: "12px" }}
        />
      );
    }

    return (
      <Space direction="vertical" size="small" style={{ width: "100%" }}>
        {requests.map((request) => (
          <GroupMembershipRequestCardMobile
            key={request.user_id}
            request={request}
            isAdmin={isAdmin}
            isReviewing={isReviewingMembership}
            onApprove={handleApprove}
            onReject={handleReject}
          />
        ))}
      </Space>
    );
  };

  return (
    <Space direction="vertical" size="medium" style={{ width: "100%" }}>
      <Segmented
        value={activeTab}
        onChange={setActiveTab}
        options={[
          {
            label: `Members ${memberCount > 0 ? `(${memberCount})` : ""}`,
            value: "members",
            icon: <UserOutlined />,
          },
          {
            label: `Requests ${requestCount > 0 ? `(${requestCount})` : ""}`,
            value: "requests",
            icon: <ClockCircleOutlined />,
          },
        ]}
        block
        style={{ fontSize: "12px" }}
      />

      {isAdmin && activeTab === "members" && (
        <Button
          type="primary"
          icon={<UserAddOutlined />}
          onClick={() => setIsAddMemberModalVisible(true)}
          block
          size="small"
        >
          Add Member
        </Button>
      )}

      {renderContent()}

      <AddGroupMemberModal
        visible={isAddMemberModalVisible}
        onClose={() => setIsAddMemberModalVisible(false)}
        familyId={familyId}
        groupId={groupId}
        currentGroupMembers={members}
        onSuccess={handleAddMemberSuccess}
      />
    </Space>
  );
};

export default GroupMembersMobile;
