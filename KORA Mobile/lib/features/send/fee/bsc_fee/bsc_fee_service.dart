import '../ethereum_fee/ethereum_fee_service.dart';

/// BSC Fee Service (uses Ethereum fee service)
class BscFeeService extends EthereumFeeService {
  BscFeeService() : super('bsc');
}
