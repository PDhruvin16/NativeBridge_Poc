export type Detection = {
    label: string;
    confidence: number;
};
interface MyNativeBridgeInterface {
    startObjectDetection(): Promise<Detection[]>;
    stopObjectDetection(): void;
}
declare const MyNativeBridge: MyNativeBridgeInterface;
export default MyNativeBridge;
//# sourceMappingURL=index.d.ts.map