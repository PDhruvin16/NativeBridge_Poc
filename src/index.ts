import { NativeModules } from 'react-native';

export type Detection = {
  label: string;
  confidence: number;
};

interface MyNativeBridgeInterface {
  startObjectDetection(): Promise<Detection[]>;
  stopObjectDetection(): void;
}

const { MyNativeModule } = NativeModules;

if (!MyNativeModule) {
  throw new Error(
    'MyNativeModule not found. Make sure you rebuilt the app after installing the package.'
  );
}

const MyNativeBridge: MyNativeBridgeInterface = MyNativeModule;

export default MyNativeBridge;