import React, { useState, useMemo } from "react";
import {
  Modal,
  Form,
  Select,
  Switch,
  Space,
  Typography,
  Alert,
  Avatar,
  message,
} from "antd";
import { UserOutlined, CrownOutlined } from "@ant-design/icons";
import useGetFamilyMembers from "../../../hooks/membership/useGetFamilyMembers";
import useAddGroupMember from "../../../hooks/group/membership/useAddGroupMember";

const { Text } = Typography;
const { Option } = Select;

/**
 * Modal for adding members to a group
 * Allows admins to select from family members and optionally make them admin
 */
const AddGroupMemberModal = ({
  visible,
  onClose,
  familyId,
  groupId,
  currentGroupMembers = [],
  onSuccess,
}) => {
  const [form] = Form.useForm();
  const [selectedUserId, setSelectedUserId] = useState(null);
  const [makeAdmin, setMakeAdmin] = useState(false);

  const { members: familyMembers, isFetchingMembers } =
    useGetFamilyMembers(familyId);

  const { addMember, isAddingMember } = useAddGroupMember();

  // Filter out users who are already group members
  const availableMembers = useMemo(() => {
    const currentMemberIds = new Set(currentGroupMembers.map((m) => m.user_id));
    return familyMembers.filter((m) => !currentMemberIds.has(m.user_id));
  }, [familyMembers, currentGroupMembers]);

  const handleSubmit = async () => {
    try {
      await form.validateFields();

      addMember(
        {
          familyId,
          groupId,
          targetUserId: selectedUserId,
          makeAdmin,
        },
        {
          onSuccess: () => {
            message.success(
              `Member added successfully${makeAdmin ? " as admin" : ""}`,
            );
            handleClose();
            if (onSuccess) {
              onSuccess();
            }
          },
          onError: (error) => {
            message.error(error?.message || "Failed to add member to group");
          },
        },
      );
    } catch (error) {
      console.error("Form validation failed:", error);
    }
  };

  const handleClose = () => {
    form.resetFields();
    setSelectedUserId(null);
    setMakeAdmin(false);
    onClose();
  };

  return (
    <Modal
      title="Add Member to Group"
      open={visible}
      onCancel={handleClose}
      onOk={handleSubmit}
      okText="Add Member"
      cancelText="Cancel"
      confirmLoading={isAddingMember}
      width={500}
    >
      <Form form={form} layout="vertical" style={{ marginTop: "20px" }}>
        {availableMembers.length === 0 ? (
          <Alert
            message="No Available Members"
            description="All family members are already in this group."
            type="info"
            showIcon
            style={{ marginBottom: "16px" }}
          />
        ) : (
          <>
            <Form.Item
              name="userId"
              label="Select Member"
              rules={[
                { required: true, message: "Please select a member to add" },
              ]}
            >
              <Select
                placeholder="Choose a family member"
                loading={isFetchingMembers}
                onChange={setSelectedUserId}
                showSearch
                optionFilterProp="children"
                filterOption={(input, option) =>
                  option.children.toLowerCase().includes(input.toLowerCase())
                }
              >
                {availableMembers.map((member) => (
                  <Option key={member.user_id} value={member.user_id}>
                    <Space>
                      <Avatar size="small" icon={<UserOutlined />} />
                      <span>
                        {member.user_display_name || member.user_email}
                      </span>
                      {member.user_email && member.user_display_name && (
                        <Text type="secondary" style={{ fontSize: "12px" }}>
                          ({member.user_email})
                        </Text>
                      )}
                    </Space>
                  </Option>
                ))}
              </Select>
            </Form.Item>

            <Form.Item label="Member Role">
              <Space align="center">
                <Switch
                  checked={makeAdmin}
                  onChange={setMakeAdmin}
                  checkedChildren={<CrownOutlined />}
                  unCheckedChildren={<UserOutlined />}
                />
                <Text>
                  {makeAdmin ? "Add as Admin" : "Add as Regular Member"}
                </Text>
              </Space>
              <div style={{ marginTop: "8px" }}>
                <Text type="secondary" style={{ fontSize: "12px" }}>
                  {makeAdmin
                    ? "Admins can manage group members, edit group settings, and manage queues."
                    : "Regular members can view group content and participate in queues."}
                </Text>
              </div>
            </Form.Item>

            <Alert
              message="Note"
              description="The selected user will be added to the group immediately without requiring their approval."
              type="info"
              showIcon
              style={{ marginTop: "16px" }}
            />
          </>
        )}
      </Form>
    </Modal>
  );
};

export default AddGroupMemberModal;
