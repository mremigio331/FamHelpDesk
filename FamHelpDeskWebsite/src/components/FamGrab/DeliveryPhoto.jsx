import React, { useState } from "react";
import { Button, Upload, Typography, Image, Spin, Alert, message } from "antd";
import { UploadOutlined, CameraOutlined } from "@ant-design/icons";
import axios from "axios";
import { useGetUploadUrl, usePhotoUrl } from "../../hooks/useFamGrab";

const { Text, Title } = Typography;

const DeliveryPhoto = ({ familyId, requestId, request, isClaimer }) => {
  const [uploading, setUploading] = useState(false);
  const [uploadSuccess, setUploadSuccess] = useState(false);
  const { getUploadUrlAsync, isGettingUploadUrl } =
    useGetUploadUrl(familyId);

  // Show photo if one exists
  const hasPhoto = !!request.proof_photo_key;
  const { photoUrl, isPhotoFetching, isPhotoError } = usePhotoUrl(
    familyId,
    requestId,
    hasPhoto,
  );

  // Upload mode: claimer on CLAIMED status
  if (request.status === "CLAIMED" && isClaimer) {
    const handleUpload = async (file) => {
      try {
        setUploading(true);

        // Get presigned upload URL
        const response = await getUploadUrlAsync({
          requestId,
          body: { content_type: file.type },
        });

        const uploadUrl = response?.data?.upload_url;
        if (!uploadUrl) {
          message.error("Failed to get upload URL");
          return;
        }

        // Upload directly to S3
        await axios.put(uploadUrl, file, {
          headers: {
            "Content-Type": file.type,
          },
        });

        setUploadSuccess(true);
        message.success("Photo uploaded successfully");
      } catch (error) {
        message.error("Failed to upload photo");
      } finally {
        setUploading(false);
      }
    };

    if (uploadSuccess) {
      return (
        <div>
          <Title level={5}>Delivery Photo</Title>
          <Alert
            message="Photo uploaded successfully"
            type="success"
            showIcon
          />
        </div>
      );
    }

    return (
      <div>
        <Title level={5}>Delivery Photo</Title>
        <Text type="secondary" style={{ display: "block", marginBottom: "8px" }}>
          Upload a photo as proof of delivery
        </Text>
        <Upload
          beforeUpload={(file) => {
            const isImage =
              file.type === "image/jpeg" ||
              file.type === "image/png" ||
              file.type === "image/heic";
            if (!isImage) {
              message.error("Only JPEG, PNG, and HEIC images are allowed");
              return Upload.LIST_IGNORE;
            }
            const isLt10M = file.size / 1024 / 1024 < 10;
            if (!isLt10M) {
              message.error("Image must be smaller than 10MB");
              return Upload.LIST_IGNORE;
            }
            handleUpload(file);
            return false;
          }}
          showUploadList={false}
          accept="image/jpeg,image/png,image/heic"
        >
          <Button
            icon={<CameraOutlined />}
            loading={uploading || isGettingUploadUrl}
          >
            Upload Photo
          </Button>
        </Upload>
      </div>
    );
  }

  // View mode: show photo if available
  if (hasPhoto) {
    if (isPhotoFetching) {
      return (
        <div>
          <Title level={5}>Delivery Photo</Title>
          <Spin />
        </div>
      );
    }

    if (isPhotoError) {
      return (
        <div>
          <Title level={5}>Delivery Photo</Title>
          <Alert message="Failed to load photo" type="error" showIcon />
        </div>
      );
    }

    if (photoUrl) {
      return (
        <div>
          <Title level={5}>Delivery Photo</Title>
          <Image
            src={photoUrl}
            alt="Delivery proof"
            style={{ maxWidth: "400px", borderRadius: "8px" }}
          />
        </div>
      );
    }
  }

  return null;
};

export default DeliveryPhoto;
