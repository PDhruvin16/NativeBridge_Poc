"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const react_native_1 = require("react-native");
const { MyNativeModule } = react_native_1.NativeModules;
if (!MyNativeModule) {
    throw new Error('MyNativeModule not found. Make sure you rebuilt the app after installing the package.');
}
const MyNativeBridge = MyNativeModule;
exports.default = MyNativeBridge;
//# sourceMappingURL=index.js.map