// module.exports = {
//   dependency: {
//     platforms: {
//       android: {
//         sourceDir: './android',
//       },
//     },
//   },
// };
module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.mynativebridge.MyNativePackage;',
        packageInstance: 'new MyNativePackage()',
      },
    },
  },
};