// Create an annotation around the full image
clearAllObjects()
createSelectAllObject(true);

// set basal values for Haematoxylin and miR-155
setImageType('BRIGHTFIELD_H_DAB');
setColorDeconvolutionStains(
    '{"Name" : "H-DAB estimated", ' +
    '"Stain 1" : "Hematoxylin", ' +
    '"Values 1" : "0.7778767882082012 0.5475636430647997 0.3083533024964999", ' +
    '"Stain 2" : "miR-155", ' +
    '"Values 2" : "0.35804619093813866 0.9031165095450817 0.23703057891714768", ' +
    '"Background" : "180 177 194"}'
);

// Pos Cell detection
runPlugin('qupath.imagej.detect.cells.PositiveCellDetection', [
    'detectionImageBrightfield': 'Optical density sum',
    'requestedPixelSizeMicrons': 0.3,
    'backgroundRadiusMicrons': 30.0,
    'backgroundByReconstruction': true,
    'medianRadiusMicrons': 1.0,
    'sigmaMicrons': 1.2,
    'minAreaMicrons': 5.0,
    'maxAreaMicrons': 500.0,
    'threshold': 0.05,
    'maxBackground': 2.0,
    'watershedPostProcess': true,
    'cellExpansionMicrons': 6.924198250728864,
    'includeNuclei': true,
    'smoothBoundaries': true,
    'makeMeasurements': true,
    'thresholdCompartment': 'Nucleus: miR-155 OD mean',
    'thresholdPositive1': 0.07,
    'thresholdPositive2': 0.1,
    'thresholdPositive3': 0.15,
    'singleThreshold': false
])

