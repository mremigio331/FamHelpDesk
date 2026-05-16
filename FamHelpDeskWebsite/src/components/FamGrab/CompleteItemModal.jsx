import React, { useState } from "react";
import {
  Modal,
  Upload,
  Switch,
  Typography,
  Space,
  Button,
  message,
  Alert,
} from "antd";
import { CameraOutlined, InboxOutlined } from "@ant-design/icons";
import axios from "axios";
import { useGetUploadUrl, useCompleteItems } from "../../hooks/useFamGrab";

const { Text } = Typography;
const { Dragger } = Upload;

const CompleteItemModal = ({
  visible,
  onClose,
  familyId,
  requestId,
  itemId,
  itemName,
  onSuccess,
}) => {
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [uploadedPhotoKey, setUploadedPhotoKey] = useState(null);
  const [isPhotoPublic, setIsPhotoPublic] = useState(false);

  const { getUploadUrlAsync, isGettingUploadUrl } = useGetUploadUrl(familyId);
  const { completeItems, isCompletingItems } = useCompleteItems(familyId);

  const hasPhoto = !!uploadedPhotoKey;

  const resetState = () => {
    setFile(null);
    setUploading(false);
    setUploadedPhotoKey(null);
    setIsPhotoPublic(false);
  };

  const handleFileSelect = async (selectedFile) => {
    const isImage =
      selectedFile.type === "image/jpeg" ||
      selectedFile.type === "image/png" ||
      selectedFile.type === "image/heic";
    if (!isImage) {
      message.error("Only JPEG, PNG, and HEIC images are allowed");
      return false;
    }
    const isLt10M = selectedFile.size / 1024 / 1024 < 10;
    if (!isLt10M) {
      message.error("Image must be smaller than 10MB");
      return false;
    }

    setFile(selectedFile);

    try {
      setUploading(true);

      // Get presigned upload URL
      const response = await getUploadUrlAsync({
        requestId,
        body: { item_id: itemId },
      });

      const uploadUrl = response?.data?.upload_url;
      const s3Key = response?.data?.s3_key;
      if (!uploadUrl) {
        message.error("Failed to get upload URL");
        setFile(null);
        return false;
      }

      // Upload directly to S3
      await axios.put(uploadUrl, selectedFile, {
        headers: {
          "Content-Type": selectedFile.type,
        },
      });

      setUploadedPhotoKey(s3Key);
      message.success("Photo uploaded successfully");
    } catch (error) {
      message.error("Failed to upload photo");
      setFile(null);
      setUploadedPhotoKey(null);
    } finally {
      setUploading(false);
    }

    return false;
  };

  const handleRemovePhoto = () => {
    setFile(null);
    setUploadedPhotoKey(null);
    setIsPhotoPublic(false);
  };

  const handleComplete = () => {
    const body = {
      item_ids: [itemId],
    };

    if (uploadedPhotoKey) {
      body.proof_photo_key = uploadedPhotoKey;
      body.photo_visibility = isPhotoPublic ? "public" : "private";
    }

    completeItems(
      { requestId, body },
      {
        onSuccess: () => {
          message.success("Item marked as completed!");
          resetState();
          onSuccess();
        },
        onError: (error) => {
          message.error(
            error?.response?.data?.error?.message ||
              error?.response?.data?.message ||
              "Failed to complete item",
          );
        },
      },
    );
  };

  const handleCancel = () => {
    resetState();
    onClose();
  };

  return (
    <Modal
      title="Complete Item"
      open={visible}
      onCancel={handleCancel}
      onOk={handleComplete}
      confirmLoading={isCompletingItems}
      okText="Mark Complete"
      destroyOnClose
    >
      <Space direction="vertical" size="middle" style={{ width: "100%" }}>
        <Text>
          Complete item: <Text strong>{itemName}</Text>
        </Text>

        {/* Photo Upload Section */}
        <div>
          <Text type="secondary" style={{ display: "block", marginBottom: "8px" }}>
            Upload a proof photo (optional)
          </Text>
          {!hasPhoto ? (
            <Dragger
              beforeUpload={(selectedFile) => {
                handleFileSelect(selectedFile);
                return false;
              }}
              showUploadList={false}
              accept="image/jpeg,image/png,image/heic"
              disabled={uploading || isGettingUploadUrl}
            >
              <p className="ant-upload-drag-icon">
                <InboxOutlined />
              </p>
              <p className="ant-upload-text">
                {uploading ? "Uploading..." : "Click or drag a photo to upload"}
              </p>
              <p className="ant-upload-hint">
                JPEG, PNG, or HEIC. Max 10MB.
              </p>
            </Dragger>
          ) : (
            <Alert
              message="Photo uploaded"
              description={file?.name || "Photo ready"}
              type="success"
              showIcon
              closable
              onClose={handleRemovePhoto}
            />
          )}
        </div>

        {/* Photo Visibility Toggle - only shown when photo is attached */}
        {hasPhoto && (
          <div
            style={{
              padding: "12px",
              background: "#f5f5f5",
              borderRadius: "6px",
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <div>
              <Text>Make photo public</Text>
              <br />
              <Text type="secondary" style={{ fontSize: "12px" }}>
                Public photos are visible in your review history
              </Text>
            </div>
            <Switch
              checked={isPhotoPublic}
              onChange={setIsPhotoPublic}
            />
          </div>
        )}
      </Space>
    </Modal>
  );
};

export default CompleteItemModal;
