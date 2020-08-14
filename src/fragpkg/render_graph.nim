import intsets, tables,
       ../../lib/volk

type
  RenderGraphQueueFlag* = enum
    qfGraphics
    qfCompute
    qfAsyncCompute
    qfAsyncGraphics

  RenderGraphQueueFlags = set[RenderGraphQueueFlag]

  AttachmentInfo* = object
    levels: uint

  RenderResourceKind = enum
    rkBuffer
    rkTexture

  RenderResource = ref object
    case kind: RenderResourceKind
    of rkBuffer:
      discard
    of rkTexture:
      info: ptr AttachmentInfo
      imageUsage: VkImageUsageFlags
    index: int
    usedQueues: RenderGraphQueueFlags
    writtenInPasses: IntSet
    readInPasses: IntSet

  RenderPass = ref object
    index: int
    queue: RenderGraphQueueFlag
    passName: string
    graph: RenderGraph

    getClearColorCb*: proc(a: uint; value: ptr VkClearColorValue): bool

    colorOutputs: seq[RenderResource]
    colorInputs: seq[RenderResource]
    colorScaleInputs: seq[RenderResource]

  RenderGraph* = ref object
    passes: seq[owned RenderPass]
    resources: seq[owned RenderResource]
    passToIndex: Table[string, int]
    resourceToIndex: Table[string, int]

proc newAttachmentInfo*(): AttachmentInfo =
  result.levels = 1

proc newRenderGraph*(): RenderGraph =
  result = new RenderGraph

proc newRenderPass(rg: RenderGraph; name: string; idx: int; q: RenderGraphQueueFlag): RenderPass =
  result = RenderPass(
    graph: rg,
    passName: name,
    index: idx,
    queue: q
  )

proc addPass*(rg: RenderGraph; name: string; queue: RenderGraphQueueFlag): RenderPass =
  block:
    if name in rg.passToIndex:
      result = rg.passes[rg.passToIndex[name]]
      break
    else:
      let idx = len(rg.passes)
      result = newRenderPass(rg, name, idx, queue)
      add(rg.passes, result)
      rg.passToIndex[name] = idx

proc newRenderResource(rk: RenderResourceKind; idx: int): RenderResource =
  result = RenderResource(
    kind: rk,
    index: idx
  )

proc getTextureResource(rg: RenderGraph; name: string): RenderResource =
  block:
    if name in rg.resourceToIndex:
      assert(rg.resources[rg.resourceToIndex[name]].kind == rkTexture)
      result = rg.resources[rg.resourceToIndex[name]]
      break
    else:
      let idx = len(rg.resources)
      result = newRenderResource(rkTexture, idx)
      add(rg.resources, result)
      rg.resourceToIndex[name] = idx

proc addColorOutput*(rp: RenderPass; name: string; ai: var AttachmentInfo; input = ""): RenderResource =
  result = getTextureResource(rp.graph, name)
  incl(result.usedQueues, {rp.queue})
  incl(result.writtenInPasses, rp.index)
  result.info = addr(ai)
  result.imageUsage = result.imageUsage or uint32(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT)

  if ai.levels != 1:
    result.imageUsage = result.imageUsage or (uint32(VK_IMAGE_USAGE_TRANSFER_DST_BIT) or uint32(VK_IMAGE_USAGE_TRANSFER_SRC_BIT))

  add(rp.colorOutputs, result)
  
  if len(input) != 0:
    let inputRes = getTextureResource(rp.graph, input)
    incl(inputRes.readInPasses, rp.index)
    inputRes.imageUsage = inputRes.imageUsage or uint32(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT)
    add(rp.colorInputs, inputRes)
    add(rp.colorScaleInputs, nil)
  else:
    add(rp.colorInputs, nil)
    add(rp.colorScaleInputs, nil)
