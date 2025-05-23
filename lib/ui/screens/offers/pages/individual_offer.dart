import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:doseform/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sevaexchange/flavor_config.dart';
import 'package:sevaexchange/ui/screens/members/pages/members_page.dart';
import 'package:sevaexchange/ui/screens/offers/widgets/custom_dose_text_field.dart';
import 'package:sevaexchange/labels.dart';
import 'package:sevaexchange/utils/extensions.dart';
import 'package:sevaexchange/components/common_help_icon.dart';
import 'package:sevaexchange/components/duration_picker/offer_duration_widget.dart';
import 'package:sevaexchange/components/goods_dynamic_selection_editRequest.dart';
import 'package:sevaexchange/components/repeat_availability/edit_repeat_widget.dart';
import 'package:sevaexchange/components/repeat_availability/repeat_widget.dart';
import 'package:sevaexchange/constants/dropdown_currency_constants.dart';
import 'package:sevaexchange/l10n/l10n.dart';
import 'package:sevaexchange/models/currency_model.dart';
import 'package:sevaexchange/models/enums/help_context_enums.dart';
import 'package:sevaexchange/models/enums/lending_borrow_enums.dart';
import 'package:sevaexchange/models/location_model.dart';
import 'package:sevaexchange/models/models.dart';
import 'package:sevaexchange/new_baseline/models/community_model.dart';
import 'package:sevaexchange/new_baseline/models/lending_model.dart';
import 'package:sevaexchange/new_baseline/models/lending_place_model.dart';
import 'package:sevaexchange/ui/screens/borrow_agreement/borrow_agreement_pdf.dart';
import 'package:sevaexchange/ui/screens/calendar/add_to_calander.dart';
import 'package:sevaexchange/ui/screens/offers/bloc/individual_offer_bloc.dart';
import 'package:sevaexchange/ui/screens/offers/bloc/one_to_many_offer_bloc.dart';
import 'package:sevaexchange/ui/screens/offers/pages/add_update_lending_place.dart';
import 'package:sevaexchange/ui/screens/offers/pages/agreementForm.dart';
import 'package:sevaexchange/ui/screens/offers/pages/select_lending_place.dart';
import 'package:sevaexchange/ui/screens/offers/widgets/custom_dialog.dart';
import 'package:sevaexchange/ui/screens/offers/widgets/custom_textfield.dart';
import 'package:sevaexchange/ui/screens/offers/widgets/lending_item_card_widget.dart';
import 'package:sevaexchange/ui/utils/offer_utility.dart';
import 'package:sevaexchange/ui/utils/validators.dart';
import 'package:sevaexchange/utils/app_config.dart';
import 'package:sevaexchange/utils/firestore_manager.dart' as FirestoreManager;
import 'package:sevaexchange/utils/helpers/configuration_check.dart';
import 'package:sevaexchange/utils/helpers/transactions_matrix_check.dart';
import 'package:sevaexchange/utils/log_printer/log_printer.dart';
import 'package:sevaexchange/views/core.dart';
import 'package:sevaexchange/views/timebanks/widgets/loading_indicator.dart';
import 'package:sevaexchange/widgets/custom_buttons.dart';
import 'package:sevaexchange/widgets/custom_drop_down.dart';
import 'package:sevaexchange/widgets/custom_info_dialog.dart';
import 'package:sevaexchange/widgets/hide_widget.dart';
import 'package:sevaexchange/widgets/location_picker_widget.dart';
import 'package:sevaexchange/widgets/open_scope_checkbox_widget.dart';

import 'add_update_lending_item.dart';
import '../widgets/lending_place_card_widget.dart';

class IndividualOffer extends StatefulWidget {
  final OfferModel offerModel;
  final String timebankId;
  final String loggedInMemberUserId;
  final TimebankModel timebankModel;

  const IndividualOffer(
      {Key? key,
      required this.offerModel,
      required this.timebankId,
      required this.loggedInMemberUserId,
      required this.timebankModel})
      : super(key: key);

  @override
  _IndividualOfferState createState() => _IndividualOfferState();
  Future<void> openPdfViewer(
      String pdfURL, String documentName, BuildContext context) async {
    // You may need to adjust this implementation to match your app's PDF viewer and navigation logic.
    // The following is based on the pattern in agreementForm.dart.
    // If you have a ProgressDialog or PDFScreen widget, use them here. Otherwise, use your own widgets.
    // Remove or replace ProgressDialog if not available in your project.
    // Show loading indicator if needed.
    // Example assumes you have a PDFScreen widget that takes pdfUrl, docName, and pathPDF.
    // If not, replace with your actual PDF viewer widget.
    // You may need to implement createFileOfPdfUrl or use your own file loader.
    // For now, just open the URL in a new screen.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(documentName),
          ),
          // Replace the following with your actual PDF viewer widget.
          body: Center(
            child: Text('Display PDF from $pdfURL here.'),
          ),
        ),
      ),
    );
  }
}

class _IndividualOfferState extends State<IndividualOffer> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  final GlobalKey<DoseFormState> _formKey = GlobalKey();
  final _timeKey = GlobalKey();
  final IndividualOfferBloc _bloc = IndividualOfferBloc();
  final OneToManyOfferBloc _one_to_many_bloc = OneToManyOfferBloc();

  CommunityModel? communityModel;
  String selectedAddress = '';
  CustomLocation? customLocation;
  String borrowAgreementLinkFinal = '';
  String agreementIdFinal = '';
  String documentName = '';
  Map<String, dynamic> agreementConfig = {};

  // String title = '';
  String title_hint = '';
  String description_hint = '';

  TextEditingController _titleController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _availabilityController = TextEditingController();
  TextEditingController _minimumCreditsController = TextEditingController();
  TextEditingController _donationAmountController = TextEditingController();
  LendingPlaceModel? lendingPlaceModel;
  LendingModel? selectedLendingModel;

  //one_to_many
  TextEditingController _one_to_many_titleController = TextEditingController();
  TextEditingController _preparationController = TextEditingController();
  TextEditingController _classHourController = TextEditingController();
  TextEditingController _sizeClassController = TextEditingController();
  TextEditingController _classDescriptionController = TextEditingController();
  End end = End(endType: '', on: 0, after: 0);
  String title = '';
  bool closePage = true;

  FocusNode _title = FocusNode();
  FocusNode _description = FocusNode();
  FocusNode _availability = FocusNode();
  FocusNode _minimumCredits = FocusNode();
  FocusNode _donationFocusNode = FocusNode();
  List<FocusNode>? oneToManyFocusNodes;
  List<CurrencyModel> currencyList = CurrencyModel().getCurrency();
  RequestType? offerType;
  final LayerLink _layerLink = LayerLink();
  int indexSelected = -1;
  bool isDropdownOpened = false;
  bool isNeedCloseDropDown = false;
  bool shouldPop = true;
  bool lendingitemsShowPublic = false;
  bool shouldCreateOffer = true;
  bool isGoodsSelected = false;

  @override
  void initState() {
    oneToManyFocusNodes = List.generate(5, (_) => FocusNode());

    if (widget.offerModel != null) {
      if (widget.offerModel.offerType == OfferType.INDIVIDUAL_OFFER) {
        _bloc.loadData(widget.offerModel);
        _titleController.text =
            widget.offerModel.individualOfferDataModel!.title;
        _descriptionController.text =
            widget.offerModel.individualOfferDataModel!.description;
        _minimumCreditsController.text = widget
            .offerModel.individualOfferDataModel!.minimumCredits
            .toString();
        _availabilityController.text =
            widget.offerModel.individualOfferDataModel!.schedule;
        _donationAmountController.text =
            widget.offerModel.cashModel?.targetAmount != null
                ? widget.offerModel.cashModel!.targetAmount.toString()
                : '';
        offerType = widget.offerModel.type;
        _bloc.onTypeChanged(widget.offerModel.type!);
        if (widget.offerModel.type == RequestType.LENDING_OFFER) {
          _bloc.lendingOfferType = widget.offerModel.lendingOfferDetailsModel!
                      .lendingModel!.lendingType ==
                  LendingType.PLACE
              ? 0
              : 1;
          _bloc.lendingOfferTypeMode = widget.offerModel
                      .lendingOfferDetailsModel!.lendingOfferTypeMode ==
                  'SPOT_ON'
              ? 0
              : 1;
          if (widget.offerModel.lendingOfferDetailsModel!
                  .lendingOfferAgreementLink !=
              null) {
            borrowAgreementLinkFinal = widget.offerModel
                    .lendingOfferDetailsModel!.lendingOfferAgreementLink ??
                '';
            agreementIdFinal =
                widget.offerModel.lendingOfferDetailsModel!.agreementId ?? '';
            documentName = widget.offerModel.lendingOfferDetailsModel!
                    .lendingOfferAgreementName ??
                '';
            agreementConfig =
                widget.offerModel.lendingOfferDetailsModel!.agreementConfig ??
                    {};
          }
        }

        //If a Lending Item Offer is Virtual then show the public checkbox
        if (widget.offerModel.virtual == true &&
            offerType == RequestType.LENDING_OFFER &&
            widget.offerModel.lendingOfferDetailsModel!.lendingModel!
                    .lendingType ==
                LendingType.ITEM) {
          lendingitemsShowPublic = true;
          setState(() {});
        }
      } else {
        _one_to_many_bloc.loadData(widget.offerModel);
        _one_to_many_titleController.text =
            widget.offerModel.groupOfferDataModel!.classTitle!;
        _preparationController.text = widget
            .offerModel.groupOfferDataModel!.numberOfPreperationHours
            .toString();
        _classHourController.text = widget
            .offerModel.groupOfferDataModel!.numberOfClassHours
            .toString();
        _sizeClassController.text =
            widget.offerModel.groupOfferDataModel!.sizeOfClass.toString();
        _classDescriptionController.text =
            widget.offerModel.groupOfferDataModel!.classDescription!;
        offerType = RequestType.ONE_TO_MANY_OFFER;
        _bloc.onTypeChanged(RequestType.ONE_TO_MANY_OFFER);
      }

      AppConfig.helpIconContextMember =
          widget.offerModel.type == RequestType.TIME
              ? HelpContextMemberType.time_offers
              : widget.offerModel.type == RequestType.CASH
                  ? HelpContextMemberType.money_offers
                  : widget.offerModel.type == RequestType.ONE_TO_MANY_OFFER
                      ? HelpContextMemberType.one_to_many_offers
                      : HelpContextMemberType.goods_offers;
    } else {
      AppConfig.helpIconContextMember = HelpContextMemberType.time_offers;

      _bloc.onTypeChanged(RequestType.TIME);
      offerType = RequestType.TIME;
    }

    super.initState();
    getCommunity();
    _bloc.errorMessage.listen((event) {
      if (event.isNotEmpty && event != null) {
        //hideProgress();
        showScaffold(event == 'goods'
            ? S.of(context).select_goods_category
            : event == 'lending'
                ? 'Please select lending Item/Place'
                : '');
      }
    });
    _one_to_many_bloc.classSizeError.listen((error) {
      if (error != null) {
        log(error);
        errorDialog(
          context: context,
          error: getValidationError(context, error),
        );
      }
    });
  }

  Future<void> getCommunity() async {
    Future.delayed(Duration.zero, () async {
      communityModel = await FirestoreManager.getCommunityDetailsByCommunityId(
          communityId: SevaCore.of(context).loggedInUser.currentCommunity!);

      if (widget.offerModel == null ||
          (widget.offerModel != null &&
              widget.offerModel.location == null &&
              widget.offerModel.selectedAdrress == null)) {
        _bloc.onLocatioChanged(CustomLocation(
          widget.timebankModel.location,
          widget.timebankModel.address,
        ));
        _one_to_many_bloc.onLocatioChanged(CustomLocation(
          widget.timebankModel.location,
          widget.timebankModel.address,
        ));
      }
      setState(() {});
    });
  }

  void showScaffold(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: S.of(context).dismiss,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bloc.dispose();
    _one_to_many_bloc.dispose();
    _title.dispose();
    _description.dispose();
    _availability.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _availabilityController.dispose();
    _minimumCreditsController.dispose();
    _one_to_many_titleController.dispose();
    _preparationController.dispose();
    _classHourController.dispose();
    _sizeClassController.dispose();
    _classDescriptionController.dispose();
    super.dispose();
  }

  bool showVirtual(int lendingOfferType) {
    if (offerType == RequestType.ONE_TO_MANY_OFFER) return true;
    if (offerType == RequestType.LENDING_OFFER) {
      if (lendingOfferType == 0)
        return true;
      else
        return false;
    }
    return false;
  }

  Widget _optionRadioButton(
      {String? title, value, groupvalue, Function? onChanged}) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: 0.0, right: 0.0),
      title: Text(title!),
      leading: Radio(
          value: value,
          groupValue: groupvalue,
          onChanged: onChanged as ValueChanged<dynamic>?),
    );
  }

  Widget RequestTypeWidget() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StreamBuilder<RequestType>(
              stream: _bloc.type,
              builder: (context, snapshot) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).offer_type,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Europa',
                        color: Colors.black,
                      ),
                    ),
                    Column(
                      children: <Widget>[
                        ConfigurationCheck(
                          actionType: 'create_time_offers',
                          role: MemberType.SUPER_ADMIN,
                          child: _optionRadioButton(
                            title: S.of(context).request_type_time,
                            value: RequestType.TIME,
                            groupvalue: snapshot.data != null
                                ? snapshot.data
                                : RequestType.TIME,
                            onChanged: (data) {
                              AppConfig.helpIconContextMember =
                                  HelpContextMemberType.time_offers;
                              _bloc.onTypeChanged(data);
                              title_hint = S.of(context).offer_title_hint;
                              description_hint =
                                  S.of(context).offer_description_hint;
                              offerType = data;

                              setState(() {});
                            },
                          ),
                        ),
                        TransactionsMatrixCheck(
                          upgradeDetails: AppConfig
                              .upgradePlanBannerModel!.cash_goods_offers!,
                          transaction_matrix_type: "cash_goods_offers",
                          comingFrom: ComingFrom.Offers,
                          child: ConfigurationCheck(
                            actionType: 'create_money_offers',
                            role: MemberType.SUPER_ADMIN,
                            child: _optionRadioButton(
                                title: S.of(context).request_type_cash,
                                value: RequestType.CASH,
                                groupvalue: snapshot.data != null
                                    ? snapshot.data
                                    : RequestType.TIME,
                                onChanged: (data) {
                                  AppConfig.helpIconContextMember =
                                      HelpContextMemberType.money_offers;
                                  _bloc.onTypeChanged(data);
                                  title_hint =
                                      S.of(context).cash_offer_title_hint;
                                  description_hint =
                                      S.of(context).cash_offer_desc_hint;
                                  offerType = data;

                                  setState(() {});
                                }),
                          ),
                        ),
                        TransactionsMatrixCheck(
                          upgradeDetails: AppConfig
                              .upgradePlanBannerModel!.cash_goods_offers!,
                          transaction_matrix_type: "cash_goods_offers",
                          comingFrom: ComingFrom.Offers,
                          child: ConfigurationCheck(
                            actionType: 'create_goods_offers',
                            role: MemberType.SUPER_ADMIN,
                            child: _optionRadioButton(
                                title: S.of(context).request_type_goods,
                                value: RequestType.GOODS,
                                groupvalue: snapshot.data != null
                                    ? snapshot.data
                                    : RequestType.TIME,
                                onChanged: (data) {
                                  AppConfig.helpIconContextMember =
                                      HelpContextMemberType.goods_offers;
                                  title_hint =
                                      S.of(context).goods_offer_title_hint;
                                  description_hint =
                                      S.of(context).goods_offer_desc_hint;
                                  _bloc.onTypeChanged(data);
                                  offerType = data;
                                  setState(() {});
                                }),
                          ),
                        ),
                        TransactionsMatrixCheck(
                          upgradeDetails:
                              AppConfig.upgradePlanBannerModel!.lending_offers!,
                          transaction_matrix_type: "lending_offer",
                          comingFrom: ComingFrom.Offers,
                          child: ConfigurationCheck(
                            actionType: 'create_lending_offers',
                            role: MemberType.MEMBER,
                            child: _optionRadioButton(
                                title: S.of(context).lend_text,
                                value: RequestType.LENDING_OFFER,
                                groupvalue: snapshot.data != null
                                    ? snapshot.data
                                    : RequestType.LENDING_OFFER,
                                onChanged: (data) {
                                  AppConfig.helpIconContextMember =
                                      HelpContextMemberType.lending_offers;
                                  _bloc.onTypeChanged(data);
                                  offerType = data;
                                  title_hint = (_bloc.lendingOfferType == 0
                                      ? S
                                          .of(context)
                                          .lending_offer_title_hint_place
                                      : S
                                          .of(context)
                                          .lending_offer_title_hint_item);
                                  description_hint = (_bloc.lendingOfferType ==
                                          0
                                      ? S
                                          .of(context)
                                          .lending_offer_description_hint_place
                                      : S
                                          .of(context)
                                          .lending_offer_description_hint_item);

                                  setState(() {});
                                }),
                          ),
                        ),
                        TransactionsMatrixCheck(
                          upgradeDetails: AppConfig
                              .upgradePlanBannerModel!.onetomany_offers!,
                          transaction_matrix_type: "onetomany_offers",
                          comingFrom: ComingFrom.Offers,
                          child: ConfigurationCheck(
                            actionType: 'one_to_many_offer',
                            role: MemberType.MEMBER,
                            child: _optionRadioButton(
                                title: S.of(context).one_to_many.sentenceCase(),
                                value: RequestType.ONE_TO_MANY_OFFER,
                                groupvalue: snapshot.data != null
                                    ? snapshot.data
                                    : RequestType.TIME,
                                onChanged: (data) {
                                  AppConfig.helpIconContextMember =
                                      HelpContextMemberType.one_to_many_offers;
                                  _bloc.onTypeChanged(data);
                                  offerType = data;

                                  setState(() {});
                                }),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              })
        ]);
  }

  Widget TimeRequest() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StreamBuilder<String>(
            stream: _bloc.availability,
            builder: (context, snapshot) {
              return CustomDoseTextField(
                isRequired: true,
                controller: _availabilityController,
                focusNode: _availability,
                validator: (val) {
                  var validate = _bloc.validateAvailabilityField(val!);
                  return getValidationError(context, validate);
                },
                value: snapshot.data,
                heading: S.of(context).availablity + '*',
                onChanged: _bloc.onAvailabilityChanged,
                hint: S.of(context).availablity_description,
                maxLength: 100,
              );
            },
          ),
          StreamBuilder<String>(
            stream: _bloc.minimumCredits,
            builder: (context, snapshot) {
              return CustomDoseTextField(
                isRequired: true,
                controller: _minimumCreditsController,
                focusNode: _minimumCredits,
                validator: (val) {
                  var validate = _bloc.validateMinimumCredits(val!);
                  return getValidationError(context, validate);
                },
                value: snapshot.data,
                heading: S.of(context).minimum_credit_title,
                onChanged: _bloc.onMinimumCreditsChanged,
                hint: S.of(context).minimum_credit_hint,
                maxLength: 100,
                formatters: [
                  FilteringTextInputFormatter.allow(Regex.numericRegex)
                ],
                keyboardType: TextInputType.number,
              );
            },
          ),
          Container(
            margin: EdgeInsets.only(top: 10.0),
            alignment: Alignment.bottomLeft,
            child: CupertinoSegmentedControl<int>(
              unselectedColor: Colors.grey[200],
              selectedColor: Theme.of(context).primaryColor,
              children: {
                0: Padding(
                  padding: EdgeInsets.only(left: 14, right: 14),
                  child: Text(
                    S.of(context).option_one, //Label to be created
                    style: TextStyle(fontSize: 12.0),
                  ),
                ),
                1: Padding(
                  padding: EdgeInsets.only(left: 14, right: 14),
                  child: Text(
                    S.of(context).option_two, //Label to be created
                    style: TextStyle(fontSize: 12.0),
                  ),
                ),
              },

              borderColor: Colors.grey,
              padding: EdgeInsets.only(left: 0.0, right: 0.0),
              groupValue: _bloc.timeOfferType,
              onValueChanged: (int val) {
                if (val != _bloc.timeOfferType) {
                  setState(() {
                    if (val == 0) {
                      _bloc.timeOfferType = 0;
                    } else {
                      _bloc.timeOfferType = 1;
                    }
                    _bloc.timeOfferType = val;
                  });
                }
              },
              //groupValue: sharedValue,
            ),
          ),
        ]);
  }

  String defaultOfferCurrenyType = kDefaultCurrencyType;
  String defaultImage = kDefaultFlagImageUrl;

  Widget CashRequest() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StreamBuilder<int>(
            stream: _bloc.donationAmount,
            builder: (context, snapshot) {
              return DoseTextField(
                isRequired: true,
                controller: _donationAmountController,
                focusNode: _donationFocusNode,
                validator: (val) {
                  var validate = _bloc.validateAmount(val!);
                  logger.e(
                      "#validate AMT  ${getValidationError(context, validate)}");
                  return validate == null
                      ? null
                      : getValidationError(context, validate);
                },
                onChanged: (String data) =>
                    _bloc.onDonationAmountChanged(int.tryParse(data) ?? 0),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: S.of(context).add_amount_donate ?? '',
                  errorText: snapshot.error != null
                      ? getValidationError(context, snapshot.error.toString())
                      : null,
                  prefixIcon: StreamBuilder<String>(
                      stream: _bloc.offeredCurrency,
                      builder: (context, snapshot) {
                        return Container(
                          width: 90,
                          child: CompositedTransformTarget(
                            link: _layerLink,
                            child: CustomDropdownView(
                              layerLink: _layerLink,
                              isNeedCloseDropdown: isNeedCloseDropDown,
                              elevationShadow: 20,
                              decorationDropdown: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              defaultWidget: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      indexSelected != -1
                                          ? "${currencyList[indexSelected].code}"
                                          : widget.offerModel == null
                                              ? defaultOfferCurrenyType
                                              : widget.offerModel.cashModel!
                                                  .offerCurrencyType!,
                                      style: kDropDownChildCurrencyCode,
                                    ),
                                    SizedBox(width: 8),
                                    StreamBuilder<String>(
                                        stream: _bloc.offerFlag,
                                        builder: (context, snapshot) {
                                          return Container(
                                            height: kFlagImageContainerHeight,
                                            width: kFlagImageContainerWidth,
                                            child: Image.network(
                                              widget.offerModel == null
                                                  ? defaultImage
                                                  : widget.offerModel.cashModel!
                                                      .offerCurrencyFlag!,
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        }),
                                    SizedBox(width: 8),
                                    isDropdownOpened
                                        ? Icon(
                                            Icons.keyboard_arrow_up,
                                            color: Color(0xFF737579),
                                          )
                                        : kDropDownArrowIcon,
                                  ],
                                ),
                              ),
                              onTapDropdown: (bool _isDropdownOpened) async {
                                await Future.delayed(Duration.zero);
                                setState(() {
                                  isDropdownOpened = _isDropdownOpened;
                                  if (_isDropdownOpened == false)
                                    isNeedCloseDropDown = false;
                                });
                              },
                              listWidgetItem:
                                  List.generate(currencyList.length, (index) {
                                return GestureDetector(
                                  onTap: () {
                                    indexSelected = index;
                                    isNeedCloseDropDown = true;

                                    if (widget.offerModel == null) {
                                      setState(() {
                                        defaultOfferCurrenyType =
                                            currencyList[indexSelected].code!;
                                        _bloc.offeredCurrencyType(
                                            currencyList[indexSelected].code!);
                                        defaultImage =
                                            currencyList[indexSelected]
                                                .imagePath!;
                                        _bloc.offerCurrencyflag(
                                            currencyList[indexSelected]
                                                .imagePath!);
                                      });
                                    }
                                    setState(() {
                                      widget.offerModel.cashModel!
                                              .offerCurrencyType =
                                          currencyList[indexSelected].code;
                                      widget.offerModel.cashModel!
                                              .offerCurrencyFlag =
                                          currencyList[indexSelected].imagePath;
                                      _bloc.offeredCurrencyType(
                                          currencyList[indexSelected].code!);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        top: index == 0
                                            ? Radius.circular(4)
                                            : Radius.zero,
                                        bottom: index == currencyList.length - 1
                                            ? Radius.circular(4)
                                            : Radius.zero,
                                      ),
                                      color: indexSelected == index
                                          ? Color(0xFFE8EFFF)
                                          : Colors.white,
                                    ),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: Container(
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            height: 10,
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                height: 12,
                                                width: 16,
                                                child: Image.network(
                                                  "${currencyList[index].imagePath}",
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 8,
                                              ),
                                              Text(
                                                "${currencyList[index].code}",
                                                style:
                                                    kDropDownChildCurrencyCode,
                                              ),
                                              SizedBox(
                                                width: 8,
                                              ),
                                              Text(
                                                "${currencyList[index].name}",
                                                style:
                                                    kDropDownChildCurrencyName,
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: 9,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      }),
                ),
                formatters: [
                  FilteringTextInputFormatter.allow(
                    (RegExp("[0-9]")),
                  ),
                ],
                keyboardType: TextInputType.number,
                // initialValue: widget.offerModel != null
                //     ? widget.offerModel.cashModel.targetAmount.toString()
                //     : '',
                onFieldSubmitted: (v) {
                  _availability.unfocus();
                  _bloc.onDonationAmountChanged(int.tryParse(v ?? '0') ?? 0);
                },
              );
            },
          ),
        ]);
  }

  Widget RequestGoodsDescriptionData(GoodsDonationDetails requestGoodsData) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            S.of(context).request_goods_offer.replaceAll("  ", " "),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Europa',
              color: Colors.black,
            ),
          ),
          GoodsDynamicSelection(
            goodsbefore: requestGoodsData.requiredGoods ?? {},
            onSelectedGoods: (goods) => {
              requestGoodsData.requiredGoods = goods.cast<String, String>(),
              _bloc.onGoodsDetailsChanged(requestGoodsData)
            },
          )
        ]);
  }

  TextStyle hintTextStyle = TextStyle(
    fontSize: 14,
    // fontWeight: FontWeight.bold,
    color: Colors.grey,
    fontFamily: 'Europa',
  );

  int timeTypeSelection = 0;

  Widget GoodsRequest() {
    return StreamBuilder<GoodsDonationDetails>(
      stream: _bloc.goodsDonationDetails,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingIndicator();
        } else if (snapshot.hasError) {
          var validate = _bloc.validateGoods();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),
              RequestGoodsDescriptionData(GoodsDonationDetails(
                  donors: <String>[], address: '', requiredGoods: {})),
              Center(
                child: Text(
                  validate == 'add_goods_donate_empty'
                      ? S.of(context).add_goods_donate_empty
                      : snapshot.error.toString(),
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        } else {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: 10),
                RequestGoodsDescriptionData(snapshot.data!),
              ]);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: widget.offerModel != null
          ? AppBar(
              backgroundColor: Theme.of(context).primaryColor,
              title: Text(
                S.of(context).edit,
                style: TextStyle(fontSize: 18),
              ),
              actions: [CommonHelpIconWidget()])
          : null,
      body: SafeArea(
        child: StreamBuilder<Status>(
          stream: offerType == RequestType.ONE_TO_MANY_OFFER
              ? _one_to_many_bloc.status
              : _bloc.status,
          builder: (context, status) {
            if (status.data == Status.COMPLETE) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) {
                  if (Navigator.canPop(context) && shouldPop) {
                    shouldPop = false;
                    Navigator.of(context).pop();
                  }
                },
              );
            }

            if (status.data == Status.LOADING) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.offerModel == null
                            ? S.of(context).creating_offer
                            : S.of(context).updating_offer,
                      ),
                    ),
                  );
                },
              );
            }

            if (status.data == Status.ERROR) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.offerModel == null
                            ? S.of(context).offer_error_creating
                            : S.of(context).offer_error_updating,
                      ),
                    ),
                  );
                },
              );
            }

            return DoseForm(
              formKey: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Column(
                        children: <Widget>[
                          SizedBox(height: 20),
                          widget.offerModel == null
                              ? RequestTypeWidget()
                              // ? Container()
                              : Container(),
                          SizedBox(height: 10),
                          HideWidget(
                            secondChild: Container(),
                            hide: offerType == RequestType.ONE_TO_MANY_OFFER,
                            child: StreamBuilder<String>(
                              stream: _bloc.title,
                              builder: (context, snapshot) {
                                return CustomDoseTextField(
                                  isRequired: true,
                                  controller: _titleController,
                                  validator: (val) {
                                    // _bloc.validateTitle(val);
                                    var titleVal = _bloc.validateTitle(val!);
                                    return titleVal == null
                                        ? null
                                        : getValidationError(context, titleVal);
                                  },
                                  focusNode: _title,
                                  nextNode: _description,
                                  value: snapshot.data,
                                  heading: "${S.of(context).title}*",
                                  onChanged: (String value) {
                                    _bloc.onTitleChanged(value);
                                    // title = value;
                                  },
                                  hint: title_hint != null
                                      ? title_hint
                                      : offerType == RequestType.LENDING_OFFER
                                          ? (_bloc.lendingOfferType == 0
                                              ? S
                                                  .of(context)
                                                  .lending_offer_title_hint_place
                                              : S
                                                  .of(context)
                                                  .lending_offer_title_hint_item)
                                          : S.of(context).offer_title_hint,
                                  maxLength: null,
                                );
                              },
                            ),
                          ),
                          HideWidget(
                            hide: offerType == RequestType.ONE_TO_MANY_OFFER ||
                                offerType == RequestType.LENDING_OFFER,
                            child: SizedBox(height: 30),
                            secondChild: SizedBox.shrink(),
                          ),
                          HideWidget(
                            hide: offerType == RequestType.ONE_TO_MANY_OFFER ||
                                offerType == RequestType.LENDING_OFFER,
                            child: StreamBuilder<String>(
                              stream: _bloc.offerDescription,
                              builder: (context, snapshot) {
                                return CustomDoseTextField(
                                  isRequired: true,
                                  controller: _descriptionController,
                                  focusNode: _description,
                                  validator: (val) {
                                    var validate =
                                        _bloc.validateDescription(val!);
                                    return getValidationError(
                                        context, validate);
                                  },
                                  nextNode: _availability,
                                  value: snapshot.data,
                                  heading:
                                      "${S.of(context).offer_description}*",
                                  onChanged: _bloc.onOfferDescriptionChanged,
                                  hint: description_hint != null
                                      ? description_hint
                                      : S.of(context).offer_description_hint,
                                  maxLength: 500,
                                );
                              },
                            ),
                            secondChild: SizedBox.shrink(),
                          ),
                          HideWidget(
                            hide: offerType == RequestType.ONE_TO_MANY_OFFER,
                            child: SizedBox(height: 20),
                            secondChild: SizedBox.shrink(),
                          ),
                          StreamBuilder<RequestType>(
                              stream: _bloc.type,
                              builder: (context, snapshot) {
                                var type = snapshot.data != null
                                    ? snapshot.data
                                    : RequestType.TIME;
                                return type == RequestType.TIME
                                    ? TimeRequest()
                                    : type == RequestType.CASH
                                        ? CashRequest()
                                        : type == RequestType.LENDING_OFFER
                                            ? LendingOffer()
                                            : type ==
                                                    RequestType
                                                        .ONE_TO_MANY_OFFER
                                                ? OneToManyOffer()
                                                : GoodsRequest();
                              }),
                          HideWidget(
                            hide: offerType == RequestType.ONE_TO_MANY_OFFER,
                            child: SizedBox(height: 25),
                            secondChild: SizedBox.shrink(),
                          ),
                          HideWidget(
                            hide: offerType == RequestType.ONE_TO_MANY_OFFER,
                            child: StreamBuilder<CustomLocation>(
                                stream: _bloc.location,
                                builder: (context, snapshot) {
                                  return LocationPickerWidget(
                                    selectedAddress: snapshot.data!.address!,
                                    location: snapshot.data?.location,
                                    color: snapshot.error == null
                                        ? Colors.green
                                        : Colors.red,
                                    onChanged: (LocationDataModel dataModel) {
                                      _bloc.onLocatioChanged(
                                        CustomLocation(
                                          dataModel.geoPoint,
                                          dataModel.location,
                                        ),
                                      );
                                    },
                                  );
                                }),
                            secondChild: SizedBox.shrink(),
                          ),
                          HideWidget(
                              secondChild: SizedBox.shrink(),
                              hide: offerType == RequestType.ONE_TO_MANY_OFFER,
                              child: SizedBox(height: 20)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Offstage(
                              offstage: AppConfig.isTestCommunity ||
                                  offerType == RequestType.ONE_TO_MANY_OFFER ||
                                  showVirtual(_bloc.lendingOfferType),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: StreamBuilder<bool>(
                                    initialData: false,
                                    stream: _bloc.makeVirtual,
                                    builder: (context, snapshot) {
                                      return ConfigurationCheck(
                                        actionType: 'create_virtual_offer',
                                        role: MemberType.MEMBER,
                                        child: OpenScopeCheckBox(
                                            infoType: InfoType.VirtualOffers,
                                            isChecked: snapshot.data!,
                                            checkBoxTypeLabel:
                                                CheckBoxType.type_VirtualOffers,
                                            onChangedCB: (bool? val) {
                                              if (snapshot.data != val) {
                                                _bloc.onOfferMadeVirtual(val!);
                                                setState(() {});
                                              }
                                            }),
                                      );
                                    }),
                              ),
                            ),
                          ),
                          HideWidget(
                            secondChild: SizedBox.shrink(),
                            hide: showVirtual(_bloc.lendingOfferType),
                            child: StreamBuilder<bool>(
                              initialData: false,
                              stream: _bloc.isPublicVisible,
                              builder: (context, snapshot) {
                                return snapshot.data! &&
                                        // ((offerType == RequestType.LENDING_OFFER &&
                                        //     _bloc.lendingOfferType == 0)) ||
                                        // (offerType == RequestType.LENDING_OFFER &&
                                        //         _bloc.lendingOfferType == 1 &&
                                        //         lendingitemsShowPublic) &&
                                        widget.timebankId !=
                                            FlavorConfig.values.timebankId
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        child: StreamBuilder<bool>(
                                            initialData: false,
                                            stream: _bloc.makePublicValue,
                                            builder: (context, snapshot) {
                                              return TransactionsMatrixCheck(
                                                comingFrom: ComingFrom.Requests,
                                                upgradeDetails: AppConfig
                                                    .upgradePlanBannerModel!
                                                    .public_to_sevax_global!,
                                                transaction_matrix_type:
                                                    'create_public_offer',
                                                child: ConfigurationCheck(
                                                  actionType:
                                                      'create_public_offer',
                                                  role: MemberType.MEMBER,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: OpenScopeCheckBox(
                                                        infoType: InfoType
                                                            .OpenScopeOffer,
                                                        isChecked:
                                                            snapshot.data!,
                                                        checkBoxTypeLabel:
                                                            CheckBoxType
                                                                .type_Offers,
                                                        onChangedCB:
                                                            (bool? val) {
                                                          if (snapshot.data !=
                                                              val) {
                                                            _bloc
                                                                .onOfferMadePublic(
                                                                    val!);
                                                            setState(() {});
                                                          }
                                                        }),
                                                  ),
                                                ),
                                              );
                                            }),
                                      )
                                    : Container();
                              },
                            ),
                          ),
                          SizedBox(height: 20),
                          HideWidget(
                            secondChild: SizedBox.shrink(),
                            hide: offerType != RequestType.ONE_TO_MANY_OFFER,
                            child: TransactionsMatrixCheck(
                              comingFrom: ComingFrom.Offers,
                              upgradeDetails: AppConfig
                                  .upgradePlanBannerModel!.onetomany_offers!,
                              transaction_matrix_type: "onetomany_offers",
                              child: CustomElevatedButton(
                                color: Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                elevation: 2.0,
                                textColor: Colors.white,
                                onPressed: status.data == Status.LOADING
                                    ? () {}
                                    : () async {
                                        if (_formKey.currentState!.validate()) {
                                          var connResult = await Connectivity()
                                              .checkConnectivity();
                                          if (connResult ==
                                              ConnectivityResult.none) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(S
                                                    .of(context)
                                                    .check_internet),
                                                action: SnackBarAction(
                                                  label: S.of(context).dismiss,
                                                  onPressed: () =>
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .hideCurrentSnackBar(),
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          FocusScope.of(context).unfocus();
                                          if (OfferDurationWidgetState
                                                      .starttimestamp !=
                                                  0 &&
                                              OfferDurationWidgetState
                                                      .endtimestamp !=
                                                  0) {
                                            _one_to_many_bloc.startTime =
                                                OfferDurationWidgetState
                                                    .starttimestamp;
                                            _one_to_many_bloc.endTime =
                                                OfferDurationWidgetState
                                                    .endtimestamp;
                                            if (_one_to_many_bloc.endTime! <=
                                                _one_to_many_bloc.startTime!) {
                                              Scrollable.ensureVisible(
                                                  _timeKey.currentContext!);

                                              errorDialog(
                                                context: context,
                                                error: S
                                                    .of(context)
                                                    .validation_error_end_date_greater,
                                              );
                                              return;
                                            }
                                            if (DateTime
                                                    .fromMillisecondsSinceEpoch(
                                                        OfferDurationWidgetState
                                                            .starttimestamp)
                                                .isBefore(DateTime.now())) {
                                              Scrollable.ensureVisible(
                                                  _timeKey.currentContext!);

                                              errorDialog(
                                                  context: context,
                                                  error: S
                                                      .of(context)
                                                      .past_time_selected);
                                              return;
                                            }
                                            if (widget.offerModel == null) {
                                              createOneToManyOfferFunc();
                                            } else {
                                              if (widget.offerModel
                                                      .autoGenerated! ||
                                                  widget.offerModel
                                                      .isRecurring!) {
                                                showDialog(
                                                    barrierDismissible: false,
                                                    context: context,
                                                    builder: (BuildContext
                                                        viewContext) {
                                                      return WillPopScope(
                                                          onWillPop: () async {
                                                            return false;
                                                          },
                                                          child: AlertDialog(
                                                              title: Text(S
                                                                  .of(context)
                                                                  .this_is_repeating_event),
                                                              actions: [
                                                                CustomTextButton(
                                                                  child: Text(
                                                                    S
                                                                        .of(context)
                                                                        .edit_this_event,
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        color: Colors
                                                                            .red,
                                                                        fontFamily:
                                                                            'Europa'),
                                                                  ),
                                                                  onPressed:
                                                                      () async {
                                                                    Navigator.pop(
                                                                        viewContext);
                                                                    _one_to_many_bloc
                                                                            .autoGenerated =
                                                                        widget
                                                                            .offerModel
                                                                            .autoGenerated!;
                                                                    _one_to_many_bloc
                                                                            .isRecurring =
                                                                        widget
                                                                            .offerModel
                                                                            .isRecurring!;

                                                                    updateOneToManyOfferFunc(
                                                                        0);
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                ),
                                                                CustomTextButton(
                                                                  child: Text(
                                                                    S
                                                                        .of(context)
                                                                        .edit_subsequent_event,
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        color: Colors
                                                                            .red,
                                                                        fontFamily:
                                                                            'Europa'),
                                                                  ),
                                                                  onPressed:
                                                                      () async {
                                                                    Navigator.pop(
                                                                        viewContext);
                                                                    _one_to_many_bloc
                                                                            .autoGenerated =
                                                                        widget
                                                                            .offerModel
                                                                            .autoGenerated!;
                                                                    _one_to_many_bloc
                                                                            .isRecurring =
                                                                        widget
                                                                            .offerModel
                                                                            .isRecurring!;

                                                                    updateOneToManyOfferFunc(
                                                                        1);

                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                ),
                                                                CustomTextButton(
                                                                  child: Text(
                                                                    S
                                                                        .of(context)
                                                                        .cancel,
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        color: Colors
                                                                            .red,
                                                                        fontFamily:
                                                                            'Europa'),
                                                                  ),
                                                                  onPressed:
                                                                      () async {
                                                                    Navigator.pop(
                                                                        viewContext);
                                                                  },
                                                                ),
                                                              ]));
                                                    });
                                              } else {
                                                updateOneToManyOfferFunc(2);
                                                Navigator.pop(context);
                                              }
                                            }
                                          } else {
                                            FocusScope.of(context).unfocus();
                                            Scrollable.ensureVisible(
                                                _timeKey.currentContext!);
                                            errorDialog(
                                              context: context,
                                              error: S
                                                  .of(context)
                                                  .offer_start_end_date,
                                            );
                                          }
                                        } else {
                                          return;
                                        }
                                      },
                                child: status.data == Status.LOADING
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text(
                                            widget.offerModel == null
                                                ? S.of(context).creating_offer
                                                : S.of(context).updating_offer,
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(width: 8),
                                          Container(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        widget.offerModel == null
                                            ? S.of(context).create_offer
                                            : S.of(context).update_offer,
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),
                          ),
                          HideWidget(
                            hide: offerType == RequestType.ONE_TO_MANY_OFFER,
                            secondChild: Container(),
                            child: CustomElevatedButton(
                              color: Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              elevation: 2.0,
                              textColor: Colors.white,
                              onPressed: status.data == Status.LOADING
                                  ? () {}
                                  : () async {
                                      if (_formKey.currentState!.validate()) {
                                        var connResult = await Connectivity()
                                            .checkConnectivity();
                                        if (connResult ==
                                            ConnectivityResult.none) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  S.of(context).check_internet),
                                              action: SnackBarAction(
                                                label: S.of(context).dismiss,
                                                onPressed: () =>
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .hideCurrentSnackBar(),
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        if (offerType ==
                                            RequestType.LENDING_OFFER) {
                                          FocusScope.of(context).unfocus();
                                          if (_bloc.lendingOfferTypeMode == 1) {
                                            if (OfferDurationWidgetState
                                                        .starttimestamp !=
                                                    0 &&
                                                OfferDurationWidgetState
                                                        .endtimestamp !=
                                                    0) {
                                              _bloc.startTime =
                                                  OfferDurationWidgetState
                                                      .starttimestamp;
                                              _bloc.endTime =
                                                  OfferDurationWidgetState
                                                      .endtimestamp;
                                              if (_bloc.endTime! <=
                                                  _bloc.startTime!) {
                                                errorDialog(
                                                  context: context,
                                                  error: S
                                                      .of(context)
                                                      .validation_error_end_date_greater,
                                                );
                                                return;
                                              }
                                              if (DateTime
                                                      .fromMillisecondsSinceEpoch(
                                                          OfferDurationWidgetState
                                                              .starttimestamp)
                                                  .isBefore(DateTime.now())) {
                                                errorDialog(
                                                    context: context,
                                                    error: S
                                                        .of(context)
                                                        .past_time_selected);
                                                return;
                                              }

                                              if (widget.offerModel == null) {
                                                if (shouldCreateOffer) {
                                                  _bloc.createLendingOffer(
                                                      user: SevaCore.of(context)
                                                          .loggedInUser,
                                                      timebankId:
                                                          widget.timebankId,
                                                      communityName:
                                                          communityModel!
                                                                  .name ??
                                                              '',
                                                      lendingAgreementLink:
                                                          borrowAgreementLinkFinal,
                                                      agreementId:
                                                          agreementIdFinal,
                                                      lendingOfferAgreementName:
                                                          documentName,
                                                      agreementConfig:
                                                          agreementConfig);
                                                  shouldCreateOffer = false;
                                                }
                                              } else {
                                                _bloc.updateLendingOffer(
                                                    offerModel:
                                                        widget.offerModel,
                                                    lendingOfferAgreementName:
                                                        documentName ?? '',
                                                    lendingOfferAgreementLink:
                                                        borrowAgreementLinkFinal,
                                                    agreementId:
                                                        agreementIdFinal,
                                                    agreementConfig:
                                                        agreementConfig);
                                              }
                                            } else {
                                              errorDialog(
                                                context: context,
                                                error: S
                                                    .of(context)
                                                    .offer_start_end_date,
                                              );
                                            }
                                          } else {
                                            if (OfferDurationWidgetState
                                                    .starttimestamp !=
                                                0) {
                                              _bloc.startTime =
                                                  OfferDurationWidgetState
                                                      .starttimestamp;
                                              if (DateTime
                                                      .fromMillisecondsSinceEpoch(
                                                          OfferDurationWidgetState
                                                              .starttimestamp)
                                                  .isBefore(DateTime.now())) {
                                                errorDialog(
                                                    context: context,
                                                    error: S
                                                        .of(context)
                                                        .past_time_selected);
                                                return;
                                              }

                                              if (widget.offerModel == null) {
                                                if (shouldCreateOffer) {
                                                  _bloc.createLendingOffer(
                                                      user: SevaCore.of(context)
                                                          .loggedInUser,
                                                      timebankId:
                                                          widget.timebankId,
                                                      communityName:
                                                          communityModel!
                                                                  .name ??
                                                              '',
                                                      lendingAgreementLink:
                                                          borrowAgreementLinkFinal,
                                                      agreementId:
                                                          agreementIdFinal,
                                                      lendingOfferAgreementName:
                                                          documentName,
                                                      agreementConfig:
                                                          agreementConfig);
                                                  shouldCreateOffer = false;
                                                }
                                              } else {
                                                _bloc.updateLendingOffer(
                                                    offerModel:
                                                        widget.offerModel,
                                                    lendingOfferAgreementName:
                                                        documentName ?? '',
                                                    lendingOfferAgreementLink:
                                                        borrowAgreementLinkFinal,
                                                    agreementId:
                                                        agreementIdFinal,
                                                    agreementConfig:
                                                        agreementConfig);
                                              }
                                            } else {
                                              errorDialog(
                                                context: context,
                                                error: S
                                                    .of(context)
                                                    .offer_start_date_validation,
                                              );
                                            }
                                          }
                                        } else {
                                          if (offerType == RequestType.GOODS) {
                                            var validate =
                                                _bloc.validateGoods();
                                            if (validate != null) return;
                                          }

                                          if (widget.offerModel == null) {
                                            if (SevaCore.of(context)
                                                    .loggedInUser
                                                    .calendarId !=
                                                null) {
                                              _bloc.allowedCalenderEvent = true;

                                              if (shouldCreateOffer) {
                                                logger.wtf(
                                                    "createOrUpdateOffer ${shouldCreateOffer}");
                                                _bloc.createOrUpdateOffer(
                                                    user: SevaCore.of(context)
                                                        .loggedInUser,
                                                    timebankId:
                                                        widget.timebankId,
                                                    communityName:
                                                        communityModel!.name ??
                                                            '');
                                                shouldCreateOffer = false;
                                              }
                                            } else {
                                              _bloc.allowedCalenderEvent = true;
                                              if (shouldCreateOffer) {
                                                logger.wtf(
                                                    "createOrUpdateOffer ${shouldCreateOffer}");
                                                _bloc.createOrUpdateOffer(
                                                    user: SevaCore.of(context)
                                                        .loggedInUser,
                                                    timebankId:
                                                        widget.timebankId,
                                                    communityName:
                                                        communityModel!.name ??
                                                            '');
                                                shouldCreateOffer = false;
                                              }
                                              if (_bloc.offerCreatedBool) {
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) {
                                                      return AddToCalendar(
                                                          isOfferRequest: false,
                                                          offer: _bloc
                                                              .mainOfferModel!,
                                                          requestModel: RequestModel(
                                                              communityId: SevaCore
                                                                      .of(
                                                                          context)
                                                                  .loggedInUser
                                                                  .currentCommunity!),
                                                          userModel:
                                                              SevaCore.of(
                                                                      context)
                                                                  .loggedInUser,
                                                          eventsIdsArr:
                                                              _bloc.offerIds);
                                                    },
                                                  ),
                                                );
                                              }
                                            }
                                          } else {
                                            _bloc.updateIndividualOffer(
                                              widget.offerModel,
                                            );
                                          }
                                        }
                                      } else {
                                        return;
                                      }
                                    },
                              child: status.data == Status.LOADING
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          widget.offerModel == null
                                              ? S.of(context).creating_offer
                                              : S.of(context).updating_offer,
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        SizedBox(width: 8),
                                        Container(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      widget.offerModel == null
                                          ? S.of(context).create_offer
                                          : S.of(context).update_offer,
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget OneToManyOffer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: 20),
        StreamBuilder<String>(
          stream: _one_to_many_bloc.title,
          builder: (_, snapshot) {
            return CustomDoseTextField(
              isRequired: true,
              controller: _one_to_many_titleController,
              focusNode: oneToManyFocusNodes![0],
              nextNode: oneToManyFocusNodes![1],
              validator: (val) {
                var validate = _one_to_many_bloc.validateTitle(val!);
                return validate == null
                    ? null
                    : getValidationError(context, validate);
              },
              // formatters: <TextInputFormatter>[
              //   WhitelistingTextInputFormatter(
              //       RegExp("[a-zA-Z0-9_ ]*"))
              // ],
              value: snapshot.data != null ? snapshot.data : null,
              heading: "${S.of(context).title}*",
              onChanged: _one_to_many_bloc.onTitleChanged,
              hint: S.of(context).one_to_many_offer_hint,
              maxLength: null,
            );
          },
        ),
        SizedBox(height: 20),
        OfferDurationWidget(
          key: _timeKey,
          title: S.of(context).offer_duration,
          startTime: widget.offerModel != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  widget.offerModel.groupOfferDataModel!.startDate!,
                )
              : null,
          endTime: widget.offerModel != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  widget.offerModel.groupOfferDataModel!.endDate!,
                )
              : null,
        ),
        SizedBox(height: 20),
        widget.offerModel == null
            ? RepeatWidget()
            : Visibility(
                visible: widget.offerModel.isRecurring == true ||
                    widget.offerModel.autoGenerated == true,
                child: Container(
                  child: EditRepeatWidget(recurringModel: widget.offerModel),
                ),
              ),
        SizedBox(height: 20),
        StreamBuilder<String>(
          stream: _one_to_many_bloc.preparationHours,
          builder: (_, snapshot) {
            return CustomDoseTextField(
              isRequired: true,
              controller: _preparationController,
              focusNode: oneToManyFocusNodes![1],
              nextNode: oneToManyFocusNodes![2],
              validator: (val) {
                var validate = _one_to_many_bloc.validatePrepHours(val!);
                return validate == null
                    ? null
                    : getValidationError(context, validate);
              },
              value: snapshot.data != null ? snapshot.data : null,
              heading: "${S.of(context).offer_prep_hours} *",
              onChanged: _one_to_many_bloc.onPreparationHoursChanged,
              hint: S.of(context).offer_prep_hours_required,
              keyboardType: TextInputType.number,
            );
          },
        ),
        SizedBox(height: 20),
        StreamBuilder<String>(
          stream: _one_to_many_bloc.classHours,
          builder: (_, snapshot) {
            return CustomDoseTextField(
              isRequired: true,
              controller: _classHourController,
              focusNode: oneToManyFocusNodes![2],
              nextNode: oneToManyFocusNodes![3],
              validator: (val) {
                var validate = _one_to_many_bloc.validateClassHours(val!);
                return validate == null
                    ? null
                    : getValidationError(context, snapshot.error.toString());
              },
              value: snapshot.data != null ? snapshot.data : null,
              heading: "${S.of(context).offer_number_class_hours} *",
              onChanged: _one_to_many_bloc.onClassHoursChanged,
              hint: S.of(context).offer_number_class_hours_required,
              keyboardType: TextInputType.number,
            );
          },
        ),
        SizedBox(height: 20),
        StreamBuilder<String>(
          stream: _one_to_many_bloc.classSize,
          builder: (_, snapshot) {
            return CustomDoseTextField(
              isRequired: true,
              controller: _sizeClassController,
              focusNode: oneToManyFocusNodes![3],
              nextNode: oneToManyFocusNodes![4],
              validator: (val) {
                var validate = _one_to_many_bloc.validateClassSize(val!);
                return validate == null
                    ? null
                    : getValidationError(context, snapshot.error.toString());
              },
              value: snapshot.data != null ? snapshot.data : null,
              heading: "${S.of(context).offer_size_class} *",
              onChanged: _one_to_many_bloc.onClassSizeChanged,
              hint: S.of(context).offer_enter_participants,
              keyboardType: TextInputType.number,
            );
          },
        ),
        SizedBox(height: 20),
        StreamBuilder<String>(
          stream: _one_to_many_bloc.classDescription,
          builder: (_, snapshot) {
            return CustomDoseTextField(
              isRequired: true,
              controller: _classDescriptionController,
              focusNode: oneToManyFocusNodes![4],
              validator: (val) {
                var validate = _one_to_many_bloc.validateDescription(val!);
                return validate == null
                    ? null
                    : getValidationError(context, validate);
              },
              value: snapshot.data != null ? snapshot.data : null,
              heading: "${S.of(context).offer_class_description} *",
              onChanged: _one_to_many_bloc.onclassDescriptionChanged,
              hint: S.of(context).offer_description_error,
              maxLength: 500,
              keyboardType: TextInputType.multiline,
            );
          },
        ),
        SizedBox(height: 12),
        Text(S.of(context).onetomany_createoffer_note),
        SizedBox(height: 35),
        StreamBuilder<CustomLocation>(
            stream: _one_to_many_bloc.location,
            builder: (_, snapshot) {
              return LocationPickerWidget(
                location: snapshot.data?.location,
                selectedAddress: snapshot.data!.address!,
                color: snapshot.error == null ? Colors.green : Colors.red,
                onChanged: (LocationDataModel dataModel) {
                  _one_to_many_bloc.onLocatioChanged(
                    CustomLocation(
                      dataModel.geoPoint,
                      dataModel.location,
                    ),
                  );
                },
              );
            }),
        SizedBox(height: 20),
        HideWidget(
          secondChild: Container(),
          hide: AppConfig.isTestCommunity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: StreamBuilder<bool>(
                stream: _one_to_many_bloc.makeVirtualValue,
                builder: (context, snapshot) {
                  return ConfigurationCheck(
                    actionType: 'create_virtual_offer',
                    role: MemberType.MEMBER,
                    child: OpenScopeCheckBox(
                        infoType: InfoType.VirtualOffers,
                        isChecked: snapshot.data!,
                        checkBoxTypeLabel: CheckBoxType.type_VirtualOffers,
                        onChangedCB: (bool? val) {
                          if (snapshot.data != val) {
                            _one_to_many_bloc.onOfferMadeVirtual(val!);

                            logger.e('made virtual ${val}');
                            setState(() {});
                          }
                        }),
                  );
                }),
          ),
        ),
        StreamBuilder<bool>(
            initialData: false,
            stream: _one_to_many_bloc.isVisible,
            builder: (context, snapshot) {
              logger.e("is public check" + snapshot.data.toString());
              return snapshot.data!
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: StreamBuilder<bool>(
                          stream: _one_to_many_bloc.makePublicValue,
                          builder: (context, snapshot) {
                            return TransactionsMatrixCheck(
                              comingFrom: ComingFrom.Offers,
                              upgradeDetails: AppConfig.upgradePlanBannerModel!
                                  .public_to_sevax_global!,
                              transaction_matrix_type: 'create_public_offer',
                              child: ConfigurationCheck(
                                actionType: 'create_public_offer',
                                role: MemberType.MEMBER,
                                child: OpenScopeCheckBox(
                                    infoType: InfoType.OpenScopeOffer,
                                    isChecked: snapshot.data!,
                                    checkBoxTypeLabel: CheckBoxType.type_Offers,
                                    onChangedCB: (bool? val) {
                                      if (snapshot.data != val) {
                                        _one_to_many_bloc
                                            .onOfferMadePublic(val!);
                                        log('value ${val}');
                                        setState(() {});
                                      }
                                    }),
                              ),
                            );
                          }),
                    )
                  : Container();
            }),
      ],
    );
  }

  void createOneToManyOfferFunc() async {
    _one_to_many_bloc.autoGenerated = false;
    _one_to_many_bloc.isRecurring = RepeatWidgetState.isRecurring;
    if (_one_to_many_bloc.isRecurring) {
      _one_to_many_bloc.recurringDays = RepeatWidgetState.getRecurringdays();
      _one_to_many_bloc.occurenceCount = 1;
      end.endType = RepeatWidgetState.endType == 0
          ? S.of(context).on
          : S.of(context).after;
      end.on = end.endType == "on"
          ? RepeatWidgetState.selectedDate.millisecondsSinceEpoch
          : null!;
      end.after = (end.endType == S.of(context).after
          ? int.parse(RepeatWidgetState.after)
          : null!);
      _one_to_many_bloc.end = end;
    }

    if (_one_to_many_bloc.isRecurring) {
      if (_one_to_many_bloc.recurringDays.length == 0) {
        errorDialog(context: context, error: S.of(context).recurringDays_err);
        return;
      }
    }

    _one_to_many_bloc.allowedCalenderEvent = false;
    _one_to_many_bloc.createOneToManyOffer(
        context: context,
        user: SevaCore.of(context).loggedInUser,
        timebankId: widget.timebankId,
        communityName: communityModel!.name ?? '');
    _bloc.offerCreatedBool = true;
  }

  void updateOneToManyOfferFunc(int editType) async {
    if (_one_to_many_bloc.isRecurring || _one_to_many_bloc.autoGenerated) {
      _one_to_many_bloc.recurringDays =
          EditRepeatWidgetState.getRecurringdays();
      _one_to_many_bloc.occurenceCount = widget.offerModel.occurenceCount;
      end.endType = EditRepeatWidgetState.endType == 0
          ? S.of(context).on
          : S.of(context).after;
      end.on = end.endType == S.of(context).on
          ? EditRepeatWidgetState.selectedDate.millisecondsSinceEpoch
          : null!;
      end.after = (end.endType == S.of(context).after
          ? int.parse(EditRepeatWidgetState.after)
          : null!);
      _one_to_many_bloc.end = end;
    }

    if (_one_to_many_bloc.isRecurring || _one_to_many_bloc.autoGenerated) {
      if (_one_to_many_bloc.recurringDays.length == 0) {
        errorDialog(context: context, error: S.of(context).recurringDays_err);
        return;
      }
    }

    _one_to_many_bloc.updateOneToManyOffer(widget.offerModel, editType);
  }

  Widget LendingOffer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StreamBuilder<String>(
          stream: _bloc.offerDescription,
          builder: (context, snapshot) {
            return CustomDoseTextField(
              isRequired: true,
              controller: _descriptionController,
              focusNode: _description,
              nextNode: _availability,
              value: snapshot.data,
              validator: (val) {
                var validate = _bloc.validateDescription(val!);
                return getValidationError(context, validate);
              },
              heading: "${S.of(context).offer_description}*",
              onChanged: _bloc.onOfferDescriptionChanged,
              hint: description_hint != null
                  ? description_hint
                  : (_bloc.lendingOfferType == 0
                      ? S.of(context).lending_offer_description_hint_place
                      : S.of(context).lending_offer_description_hint_item),
              maxLength: 500,
              maxLines: 2,
            );
          },
        ),
        SizedBox(height: 2),
        Container(
          alignment: Alignment.bottomLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HideWidget(
                secondChild: Container(),
                hide: widget.offerModel != null,
                child: Text(
                  S.of(context).lending_text,
                  style: TextStyle(
                    fontSize: 16,
                    //fontWeight: FontWeight.bold,
                    fontFamily: 'Europa',
                    color: Colors.black,
                  ),
                ),
              ),
              HideWidget(
                secondChild: Container(),
                hide: widget.offerModel != null,
                child: SizedBox(height: 10),
              ),
              HideWidget(
                secondChild: Container(),
                hide: widget.offerModel != null,
                child: CupertinoSegmentedControl<int>(
                  unselectedColor: Colors.grey[200],
                  selectedColor: Theme.of(context).primaryColor,
                  children: {
                    0: Padding(
                      padding: EdgeInsets.only(left: 14, right: 14),
                      child: Text(
                        S.of(context).place_text, //Label to be created
                        style: TextStyle(fontSize: 12.0),
                      ),
                    ),
                    1: Padding(
                      padding: EdgeInsets.only(left: 14, right: 14),
                      child: Text(
                        S.of(context).items, //Label to be created
                        style: TextStyle(fontSize: 12.0),
                      ),
                    ),
                  },

                  borderColor: Colors.grey,
                  padding: EdgeInsets.only(left: 0.0, right: 0.0),
                  groupValue: _bloc.lendingOfferType,
                  onValueChanged: (int val) {
                    if (val != _bloc.lendingOfferType) {
                      _bloc.onLendingModelAdded(LendingModel(
                        id: '', // Provide appropriate id
                        creatorId: '', // Provide appropriate creatorId
                        email: '', // Provide appropriate email
                        timestamp: DateTime.now()
                            .millisecondsSinceEpoch, // Or appropriate timestamp
                        lendingType: _bloc.lendingOfferType == 0
                            ? LendingType.PLACE
                            : LendingType.ITEM, // Or appropriate LendingType
                      ));
                      setState(() {
                        _bloc.lendingOfferType = val;
                        selectedLendingModel = null;
                      });
                      title_hint = (_bloc.lendingOfferType == 0
                          ? S.of(context).lending_offer_title_hint_place
                          : S.of(context).lending_offer_title_hint_item);
                      description_hint = (_bloc.lendingOfferType == 0
                          ? S.of(context).lending_offer_description_hint_place
                          : S.of(context).lending_offer_description_hint_item);
                    }
                  },
                  //groupValue: sharedValue,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _bloc.lendingOfferType == 0
                  ? S.of(context).select_a_place_lending
                  : S.of(context).select_item_for_lending,
              style: TextStyle(
                fontSize: 16,
                //fontWeight: FontWeight.bold,
                fontFamily: 'Europa',
                color: Colors.black,
              ),
            ),
            // InkWell(
            //   onTap: () {
            //     if (_bloc.lendingOfferType == 1) {
            //       Navigator.of(context).push(
            //         MaterialPageRoute(
            //           builder: (context) {
            //             return AddUpdateLendingItem(
            //               lendingModel: null,
            //               enteredTitle: '',
            //               onItemCreateUpdate: (LendingModel model) {
            //                 _bloc.onLendingModelAdded(model);
            //                 setState(() {
            //                   selectedLendingModel = model;
            //                 });
            //               },
            //             );
            //           },
            //         ),
            //       );
            //     } else {
            //       Navigator.of(context).push(
            //         MaterialPageRoute(
            //           builder: (context) {
            //             return AddUpdateLendingPlace(
            //               lendingModel: null,
            //               enteredTitle: '',
            //               onPlaceCreateUpdate: (LendingModel model) {
            //                 _bloc.onLendingModelAdded(model);
            //                 setState(() {
            //                   selectedLendingModel = model;
            //                 });
            //               },
            //             );
            //           },
            //         ),
            //       );
            //     }
            //   },
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       Text(
            //         S.of(context).add_new,
            //         style: TextStyle(
            //           fontSize: 14,
            //           //fontWeight: FontWeight.bold,
            //           fontFamily: 'Europa',
            //           color: Colors.black,
            //         ),
            //       ),
            //       SizedBox(width: 3),
            //       Icon(Icons.add_circle_rounded, size: 25, color: Colors.grey[600]),
            //     ],
            //   ),
            // ),
          ],
        ),
        SizedBox(
          height: 10,
        ),
        SelectLendingPlaceItem(
          onSelected: (LendingModel model) {
            _bloc.onLendingModelAdded(model);
            setState(() {
              selectedLendingModel = model;
            });
          },
          lendingType: _bloc.lendingOfferType == 0
              ? LendingType.PLACE
              : LendingType.ITEM,
        ),
        SizedBox(
          height: 10,
        ),
        StreamBuilder<LendingModel>(
            stream: _bloc.lendingModelStream,
            builder: (context, snapshot) {
              if (snapshot.data == null || snapshot.hasError) {
                return Container();
              }
              if (snapshot.hasError) {
                return Container();
              }
              if (snapshot.data!.lendingType == LendingType.ITEM) {
                return LendingItemCardWidget(
                  lendingItemModel: snapshot.data!.lendingItemModel,
                  onDelete: () {
                    _bloc.onLendingModelAdded(
                      LendingModel(
                        id: '',
                        creatorId: '',
                        email: '',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        lendingType: LendingType.ITEM,
                      ),
                    );
                    setState(() {
                      selectedLendingModel = null;
                    });
                  },
                  onEdit: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return AddUpdateLendingItem(
                            lendingModel: snapshot.data,
                            onItemCreateUpdate: (LendingModel model) {
                              _bloc.onLendingModelAdded(model);
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              } else {
                return LendingPlaceCardWidget(
                  lendingPlaceModel: snapshot.data!.lendingPlaceModel,
                  onDelete: () {
                    _bloc.onLendingModelAdded(
                      LendingModel(
                        id: '',
                        creatorId: '',
                        email: '',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        lendingType: LendingType.PLACE,
                      ),
                    );
                    setState(() {
                      selectedLendingModel = null;
                    });
                  },
                  onEdit: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return AddUpdateLendingPlace(
                            lendingModel: snapshot.data,
                            onPlaceCreateUpdate: (LendingModel model) {
                              _bloc.onLendingModelAdded(model);
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              }
            }),
        SizedBox(height: 20),
        OfferDurationWidget(
          key: _timeKey,
          hideEndDate: _bloc.lendingOfferTypeMode != 1,
          title: S.of(context).offer_duration,
          startTime: widget.offerModel != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  widget.offerModel.lendingOfferDetailsModel!.startDate!,
                )
              : null,
          endTime: widget.offerModel != null &&
                  widget.offerModel.lendingOfferDetailsModel!
                          .lendingOfferTypeMode ==
                      'ONE_TIME'
              ? DateTime.fromMillisecondsSinceEpoch(
                  widget.offerModel.lendingOfferDetailsModel!.endDate!,
                )
              : null,
        ),
        SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context).agreement,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.68,
                  child: Text(
                    S.of(context).request_agreement_form_component_text,
                    style: TextStyle(fontSize: 14),
                    softWrap: true,
                  ),
                ),
                Image(
                  width: 50,
                  image: AssetImage(
                      'lib/assets/images/request_offer_agreement_icon.png'),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(documentName != null ? S.of(context).view : ' '),
                InkWell(
                    child: Container(
                      alignment: Alignment.topLeft,
                      width: MediaQuery.of(context).size.width * 0.55,
                      child: Text(
                        documentName != null
                            ? documentName
                            : S
                                .of(context)
                                .approve_borrow_no_agreement_selected,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: documentName != null
                                ? Theme.of(context).primaryColor
                                : Colors.grey),
                        softWrap: true,
                      ),
                    ),
                    onTap: documentName != null
                        ? () async {
                            if (documentName != '') {
                              await widget.openPdfViewer(
                                  borrowAgreementLinkFinal,
                                  documentName,
                                  context);
                            } else {
                              return null;
                            }
                          }
                        : null),
              ],
            ),
            Spacer(),
            Container(
              width: 90,
              height: 32,
              child: CustomTextButton(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.all(0),
                color: Theme.of(context).primaryColor,
                child: Row(
                  children: <Widget>[
                    SizedBox(width: 1),
                    Spacer(),
                    Text(
                      documentName != null
                          ? S.of(context).change
                          : S.of(context).add,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    Spacer(
                      flex: 1,
                    ),
                  ],
                ),
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  if (selectedLendingModel == null &&
                      widget.offerModel == null) {
                    _bloc.lendingOfferType == 0
                        ? errorDialog(
                            context: context,
                            error: S.of(context).select_a_place_lending,
                          )
                        : errorDialog(
                            context: context,
                            error: S.of(context).select_item_for_lending,
                          );
                    return;
                  }
                  if (_bloc.lendingOfferTypeMode == 1
                      ? (OfferDurationWidgetState.starttimestamp != 0 &&
                          OfferDurationWidgetState.endtimestamp != 0)
                      : OfferDurationWidgetState.starttimestamp != 0) {
                    _bloc.startTime = OfferDurationWidgetState.starttimestamp;
                    _bloc.endTime = OfferDurationWidgetState.endtimestamp;
                    if (_bloc.endTime! <= _bloc.startTime! &&
                        _bloc.timeOfferType == 1) {
                      errorDialog(
                        context: context,
                        error: S.of(context).validation_error_end_date_greater,
                      );
                      return;
                    }
                    logger.e("MODEL 1:  " + selectedLendingModel.toString());
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => AgreementForm(
                          lendingModelListBorrowRequest: [],
                          endTime: _bloc.lendingOfferTypeMode == 0
                              ? 0
                              : _bloc.endTime!,
                          startTime: _bloc.startTime!,
                          requestModel: RequestModel(
                              communityId: SevaCore.of(context)
                                  .loggedInUser
                                  .currentCommunity!),
                          lendingModel: selectedLendingModel!,
                          isOffer: true,
                          placeOrItem: _bloc.lendingOfferType == 0
                              ? LendingType.PLACE.readable
                              : LendingType.ITEM.readable,
                          communityId: SevaCore.of(context)
                              .loggedInUser
                              .currentCommunity!,
                          timebankId: widget.timebankId,
                          onPdfCreated: (pdfLink, documentNameFinal,
                              agreementConfig2, agreementId) {
                            borrowAgreementLinkFinal = pdfLink;
                            documentName = documentNameFinal;
                            agreementConfig = agreementConfig2;
                            agreementIdFinal = agreementId;
                            // when request is created check if above value is stored in document
                            setState(() => {});
                          },
                        ),
                      ),
                    );
                  } else {
                    _bloc.lendingOfferTypeMode == 0
                        ? errorDialog(
                            context: context,
                            error: S.of(context).offer_start_date_validation,
                          )
                        : errorDialog(
                            context: context,
                            error: S.of(context).offer_start_end_date,
                          );
                  }
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 22),
        Container(
          alignment: Alignment.bottomLeft,
          child: CupertinoSegmentedControl<int>(
            unselectedColor: Colors.grey[200],
            selectedColor: Theme.of(context).primaryColor,
            children: {
              0: Padding(
                padding: EdgeInsets.only(left: 14, right: 14),
                child: Text(
                  S.of(context).option_one, //Label to be created
                  style: TextStyle(fontSize: 12.0),
                ),
              ),
              1: Padding(
                padding: EdgeInsets.only(left: 14, right: 14),
                child: Text(
                  S.of(context).option_two, //Label to be created
                  style: TextStyle(fontSize: 12.0),
                ),
              ),
            },

            borderColor: Colors.grey,
            padding: EdgeInsets.only(left: 0.0, right: 0.0),
            groupValue: _bloc.lendingOfferTypeMode,
            onValueChanged: (int val) {
              if (val != _bloc.lendingOfferTypeMode) {
                setState(() {
                  if (val == 0) {
                    _bloc.lendingOfferTypeMode = 0;
                  } else {
                    _bloc.lendingOfferTypeMode = 1;
                  }
                  // _bloc.lendingOfferTypeMode = val;
                });
              }
            },
            //groupValue: sharedValue,
          ),
        ),
        SizedBox(height: 18),
        Text(
          S.of(context).address_text,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        Text(
          _bloc.lendingOfferType == 0
              ? S.of(context).lending_offer_location_hint_place
              : S.of(context).lending_offer_location_hint_item,
          style: TextStyle(fontSize: 15),
          softWrap: true,
        ),
        SizedBox(height: 5),
        Text(
          S.of(context).location_safety_disclaimer,
          style: TextStyle(fontSize: 13),
          softWrap: true,
        ),
      ],
    );
  }
}
