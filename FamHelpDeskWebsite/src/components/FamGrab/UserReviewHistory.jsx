import React, { useState, useContext, useCallback, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Card,
  Typography,
  List,
  Rate,
  Modal,
  Button,
  Spin,
  Alert,
  Image,
  Space,
  Tag,
} from "antd";
import {
  ArrowLeftOutlined,
  StarOutlined,
  CameraOutlined,
} from "@ant-design/icons";
import { useQuery } from "@tanstack/react-query";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { useApi } from "../../provider/ApiProvider";
import { apiRequestGet } from "../../api/apiRequest";

const { Title, Text } = Typography;

const PAGE_LIMIT = 20;

const UserReviewHistory = () => {
  const { familyId, userId } = useParams();
  const navigate = useNavigate();
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const [reviews, setReviews] = useState([]);
  const [lastKey, setLastKey] = useState(null);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [previewPhoto, setPreviewPhoto] = useState(null);

  // Initial fetch
  const { data, isFetching, isError, error } = useQuery({
    queryKey: ["famgrab", "reviews", familyId, userId],
    queryFn: async () => {
      const response = await apiRequestGet(
        apiEndpoint,
        `/family/${familyId}/grab/reviews/${userId}?limit=${PAGE_LIMIT}`,
        idToken,
      );
      return response.data;
    },
    enabled: !!idToken && !!familyId && !!userId,
    staleTime: 1000 * 60 * 2,
  });

  // Sync initial data into local state for pagination
  useEffect(() => {
    if (data) {
      setReviews(data.reviews || []);
      setLastKey(data.last_key || null);
    }
  }, [data]);

  const averageRating = data?.average_rating || 0;
  const totalReviewCount = data?.total_review_count || 0;

  const handleLoadMore = useCallback(async () => {
    if (!lastKey) return;

    setIsLoadingMore(true);
    try {
      const response = await apiRequestGet(
        apiEndpoint,
        `/family/${familyId}/grab/reviews/${userId}?limit=${PAGE_LIMIT}&last_key=${encodeURIComponent(lastKey)}`,
        idToken,
      );
      const newData = response.data;
      setReviews((prev) => [...prev, ...(newData.reviews || [])]);
      setLastKey(newData.last_key || null);
    } catch {
      // Silently handle pagination errors
    } finally {
      setIsLoadingMore(false);
    }
  }, [lastKey, apiEndpoint, familyId, userId, idToken]);

  const handleBack = () => {
    navigate(`/family/${familyId}/grab`);
  };

  if (isFetching && reviews.length === 0) {
    return (
      <div style={{ textAlign: "center", padding: "40px" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (isError) {
    return (
      <Alert
        message="Failed to load review history"
        description={error?.response?.data?.detail || "An error occurred"}
        type="error"
        showIcon
        action={
          <Button onClick={handleBack} type="link">
            Go Back
          </Button>
        }
      />
    );
  }

  const hasMore = !!lastKey;

  return (
    <div>
      <Button
        type="link"
        icon={<ArrowLeftOutlined />}
        onClick={handleBack}
        style={{ paddingLeft: 0, marginBottom: "16px" }}
      >
        Back to Dashboard
      </Button>

      {/* User Info Header */}
      <Card style={{ marginBottom: "16px" }}>
        <Space direction="vertical" size="small" style={{ width: "100%" }}>
          <Title level={4} style={{ margin: 0 }}>
            {userId}
          </Title>
          <Space size="middle">
            <Space>
              <Rate
                disabled
                allowHalf
                value={averageRating}
                style={{ fontSize: "16px" }}
              />
              <Text strong>{averageRating.toFixed(1)}</Text>
            </Space>
            <Tag icon={<StarOutlined />} color="blue">
              {totalReviewCount} {totalReviewCount === 1 ? "review" : "reviews"}
            </Tag>
          </Space>
        </Space>
      </Card>

      {/* Review List */}
      <Card>
        <Title level={5}>Reviews</Title>
        <List
          dataSource={reviews}
          locale={{ emptyText: "No reviews yet" }}
          renderItem={(review) => (
            <List.Item>
              <List.Item.Meta
                title={
                  <Space>
                    <Text strong>{review.item_name}</Text>
                    <Rate
                      disabled
                      value={review.star_rating}
                      style={{ fontSize: "14px" }}
                    />
                  </Space>
                }
                description={
                  <Space direction="vertical" size="small">
                    {review.comment && <Text>{review.comment}</Text>}
                    {review.created_at && (
                      <Text type="secondary" style={{ fontSize: "12px" }}>
                        {new Date(review.created_at * 1000).toLocaleDateString()}
                      </Text>
                    )}
                  </Space>
                }
              />
              {review.photo_url && (
                <div
                  style={{ cursor: "pointer" }}
                  onClick={() => setPreviewPhoto(review.photo_url)}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" || e.key === " ") {
                      setPreviewPhoto(review.photo_url);
                    }
                  }}
                  aria-label={`View photo for ${review.item_name}`}
                >
                  <Image
                    src={review.photo_url}
                    alt={`Delivery photo for ${review.item_name}`}
                    width={80}
                    height={80}
                    style={{
                      objectFit: "cover",
                      borderRadius: "8px",
                    }}
                    preview={false}
                  />
                  <div style={{ textAlign: "center", marginTop: "4px" }}>
                    <CameraOutlined style={{ fontSize: "12px", color: "#8c8c8c" }} />
                  </div>
                </div>
              )}
            </List.Item>
          )}
        />

        {/* Load More Button */}
        {hasMore && (
          <div style={{ textAlign: "center", marginTop: "16px" }}>
            <Button onClick={handleLoadMore} loading={isLoadingMore}>
              Load More
            </Button>
          </div>
        )}
      </Card>

      {/* Photo Preview Modal */}
      <Modal
        open={!!previewPhoto}
        onCancel={() => setPreviewPhoto(null)}
        footer={null}
        centered
        width="auto"
        style={{ maxWidth: "90vw" }}
      >
        {previewPhoto && (
          <Image
            src={previewPhoto}
            alt="Delivery photo full size"
            style={{ maxWidth: "100%", maxHeight: "80vh" }}
            preview={false}
          />
        )}
      </Modal>
    </div>
  );
};

export default UserReviewHistory;
