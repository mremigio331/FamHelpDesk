import { useState, useCallback } from "react";

/**
 * Custom hook for QueueDetail logic
 * Handles tab navigation and state management for queue detail view
 */
const useQueueDetail = () => {
  const [activeTab, setActiveTab] = useState("overview");
  const [isEditModalVisible, setIsEditModalVisible] = useState(false);
  const [isDeleteModalVisible, setIsDeleteModalVisible] = useState(false);

  const handleTabChange = useCallback((tab) => {
    setActiveTab(tab);
  }, []);

  const showEditModal = useCallback(() => {
    setIsEditModalVisible(true);
  }, []);

  const hideEditModal = useCallback(() => {
    setIsEditModalVisible(false);
  }, []);

  const showDeleteModal = useCallback(() => {
    setIsDeleteModalVisible(true);
  }, []);

  const hideDeleteModal = useCallback(() => {
    setIsDeleteModalVisible(false);
  }, []);

  return {
    activeTab,
    handleTabChange,
    isEditModalVisible,
    showEditModal,
    hideEditModal,
    isDeleteModalVisible,
    showDeleteModal,
    hideDeleteModal,
  };
};

export default useQueueDetail;
