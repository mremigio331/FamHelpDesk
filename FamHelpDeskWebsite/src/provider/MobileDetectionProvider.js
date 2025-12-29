import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useMemo,
} from "react";

const MobileDetectionContext = createContext();

export const MobileDetectionProvider = ({ children }) => {
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  useEffect(() => {
    const handleResize = () => {
      setWindowWidth(window.innerWidth);
    };

    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  const isMobile = useMemo(() => windowWidth <= 768, [windowWidth]);
  const isSmallMobile = useMemo(() => windowWidth <= 480, [windowWidth]);

  const value = useMemo(
    () => ({
      isMobile,
      isSmallMobile,
      windowWidth,
    }),
    [isMobile, isSmallMobile, windowWidth],
  );

  return (
    <MobileDetectionContext.Provider value={value}>
      {children}
    </MobileDetectionContext.Provider>
  );
};

export const useMobileDetection = () => {
  const context = useContext(MobileDetectionContext);
  if (!context) {
    throw new Error(
      "useMobileDetection must be used within a MobileDetectionProvider",
    );
  }
  return context;
};

export default MobileDetectionProvider;
