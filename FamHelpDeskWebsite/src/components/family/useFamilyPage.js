import { useState } from "react";

const useFamilyPage = () => {
  const [activeSection, setActiveSection] = useState("tickets");

  const handleSectionChange = (section) => {
    setActiveSection(section);
  };

  return {
    activeSection,
    handleSectionChange,
  };
};

export default useFamilyPage;
